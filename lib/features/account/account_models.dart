/// The person's own account, as the API describes it: their profile
/// (`GET /users/me/profile` and the career lists), other members' public
/// pages (`GET /members/:id`), the companies they belong to (`GET /me/companies`)
/// and their settings. Field names follow the API's.
library;

String? _str(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

int? _int(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

List<String> _strings(Object? v) => [
  for (final s in (v as List? ?? const []))
    if (s is String && s.trim().isNotEmpty) s.trim(),
];

Map<String, dynamic> _map(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};

// --- lookups ---------------------------------------------------------------------------------------------------

/// A city from the masters (`GET /locations/cities`).
class CityOption {
  const CityOption({required this.id, required this.name, this.state});

  final String id;
  final String name;
  final String? state;

  /// "Pune, Maharashtra", as the website's pickers write a place.
  String get label => state == null ? name : '$name, $state';

  factory CityOption.fromJson(Map<String, dynamic> json) =>
      CityOption(id: json['id'] as String, name: json['name'] as String? ?? '', state: _str(_map(json['state'])['name']));

  @override
  bool operator ==(Object other) => other is CityOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A company page on ICR, as a search finds it (`GET /companies?search=`).
class CompanyHit {
  const CompanyHit({required this.id, required this.name, this.city, this.logoUrl});

  final String id;
  final String name;
  final String? city;
  final String? logoUrl;

  factory CompanyHit.fromJson(Map<String, dynamic> json) => CompanyHit(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    city: _str(json['city']),
    logoUrl: _str(json['logoUrl']),
  );
}

// --- career history --------------------------------------------------------------------------------------------

/// The company page a role links to (`LinkedCompanyRefDto`).
class LinkedCompany {
  const LinkedCompany({required this.id, required this.name, this.logoUrl});

  final String id;
  final String name;
  final String? logoUrl;

  static LinkedCompany? fromJson(Object? json) {
    final m = _map(json);
    if (m['id'] is! String) return null;
    return LinkedCompany(id: m['id'] as String, name: m['name'] as String? ?? '', logoUrl: _str(m['logoUrl']));
  }
}

/// One role in the person's career history (`ExperienceDto`). [id] is null
/// for a role not saved yet.
class Experience {
  const Experience({
    this.id,
    required this.title,
    required this.organisation,
    this.company,
    this.employmentType,
    this.city,
    this.industryKeys = const [],
    required this.startYear,
    this.startMonth,
    this.endYear,
    this.endMonth,
    this.isCurrent = false,
    this.description,
    this.logoUrl,
  });

  final String? id;
  final String title;
  final String organisation;
  final LinkedCompany? company;
  final String? employmentType;
  final String? city;
  final List<String> industryKeys;
  final int startYear;
  final int? startMonth;
  final int? endYear;
  final int? endMonth;
  final bool isCurrent;
  final String? description;

  /// The employer's logo: the linked page's, or one ICR matched by name.
  final String? logoUrl;

  /// The role as `PUT /profile/experience` takes it (`cleanExperience` on the
  /// website): trimmed, empty strings left out, no end for a current role.
  Map<String, dynamic> toRow() => {
    'title': title.trim(),
    'organisation': organisation.trim(),
    'companyId': ?company?.id,
    'employmentType': ?employmentType,
    if (city != null && city!.trim().isNotEmpty) 'city': city!.trim(),
    'industryKeys': industryKeys,
    'startYear': startYear,
    'startMonth': ?startMonth,
    if (!isCurrent) 'endYear': ?endYear,
    if (!isCurrent) 'endMonth': ?endMonth,
    'isCurrent': isCurrent,
    if (description != null && description!.trim().isNotEmpty) 'description': description!.trim(),
  };

  factory Experience.fromJson(Map<String, dynamic> json) => Experience(
    id: json['id'] as String?,
    title: json['title'] as String? ?? '',
    organisation: json['organisation'] as String? ?? '',
    company: LinkedCompany.fromJson(json['company']),
    employmentType: _str(json['employmentType']),
    city: _str(json['city']),
    industryKeys: _strings(json['industryKeys']),
    startYear: _int(json['startYear']) ?? DateTime.now().year,
    startMonth: _int(json['startMonth']),
    endYear: _int(json['endYear']),
    endMonth: _int(json['endMonth']),
    isCurrent: json['isCurrent'] == true,
    description: _str(json['description']),
    // The API names it `organisationLogoUrl`: the linked page's logo, or one ICR matched by name.
    logoUrl: _str(json['organisationLogoUrl']) ?? _str(json['logoUrl']) ?? _str(_map(json['company'])['logoUrl']),
  );

  Experience copyWith({String? id}) => Experience(
    id: id ?? this.id,
    title: title,
    organisation: organisation,
    company: company,
    employmentType: employmentType,
    city: city,
    industryKeys: industryKeys,
    startYear: startYear,
    startMonth: startMonth,
    endYear: endYear,
    endMonth: endMonth,
    isCurrent: isCurrent,
    description: description,
    logoUrl: logoUrl,
  );
}

/// One qualification (`EducationDto`).
class Education {
  const Education({
    this.id,
    required this.institution,
    this.university,
    this.degree,
    this.fieldOfStudy,
    this.startYear,
    this.endYear,
    this.grade,
  });

  final String? id;
  final String institution;
  final String? university;
  final String? degree;
  final String? fieldOfStudy;
  final int? startYear;
  final int? endYear;
  final String? grade;

  /// As `PUT /profile/education` takes it (`cleanEducation`).
  Map<String, dynamic> toRow() {
    String? t(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    return {
      'institution': institution.trim(),
      'university': ?t(university),
      'degree': ?t(degree),
      'fieldOfStudy': ?t(fieldOfStudy),
      'startYear': ?startYear,
      'endYear': ?endYear,
      'grade': ?t(grade),
    };
  }

  factory Education.fromJson(Map<String, dynamic> json) => Education(
    id: json['id'] as String?,
    institution: json['institution'] as String? ?? '',
    university: _str(json['university']),
    degree: _str(json['degree']),
    fieldOfStudy: _str(json['fieldOfStudy']),
    startYear: _int(json['startYear']),
    endYear: _int(json['endYear']),
    grade: _str(json['grade']),
  );
}

/// A pause in a career (`CareerBreakDto`).
class CareerBreak {
  const CareerBreak({
    this.id,
    required this.reason,
    required this.startYear,
    this.startMonth,
    this.endYear,
    this.endMonth,
    this.isCurrent = false,
    this.description,
  });

  final String? id;
  final String reason;
  final int startYear;
  final int? startMonth;
  final int? endYear;
  final int? endMonth;
  final bool isCurrent;
  final String? description;

  Map<String, dynamic> toRow() => {
    'reason': reason,
    'startYear': startYear,
    'startMonth': ?startMonth,
    if (!isCurrent) 'endYear': ?endYear,
    if (!isCurrent) 'endMonth': ?endMonth,
    'isCurrent': isCurrent,
    if (description != null && description!.trim().isNotEmpty) 'description': description!.trim(),
  };

  factory CareerBreak.fromJson(Map<String, dynamic> json) => CareerBreak(
    id: json['id'] as String?,
    reason: json['reason'] as String? ?? 'OTHER',
    startYear: _int(json['startYear']) ?? DateTime.now().year,
    startMonth: _int(json['startMonth']),
    endYear: _int(json['endYear']),
    endMonth: _int(json['endMonth']),
    isCurrent: json['isCurrent'] == true,
    description: _str(json['description']),
  );
}

/// The five links on a profile (`SocialLinksDto`).
class ProfileLinks {
  const ProfileLinks({this.linkedin, this.website, this.twitter, this.github, this.portfolio});

  final String? linkedin;
  final String? website;
  final String? twitter;
  final String? github;
  final String? portfolio;

  static const labels = {
    'linkedinUrl': 'LinkedIn',
    'websiteUrl': 'Website',
    'twitterUrl': 'X (Twitter)',
    'githubUrl': 'GitHub',
    'portfolioUrl': 'Portfolio',
  };

  Map<String, String?> toMap() => {
    'linkedinUrl': linkedin,
    'websiteUrl': website,
    'twitterUrl': twitter,
    'githubUrl': github,
    'portfolioUrl': portfolio,
  };

  /// The links that are set, by their key.
  Map<String, String> get present => {
    for (final e in toMap().entries)
      if (e.value != null) e.key: e.value!,
  };

  factory ProfileLinks.fromJson(Map<String, dynamic> json) => ProfileLinks(
    linkedin: _str(json['linkedinUrl']),
    website: _str(json['websiteUrl']),
    twitter: _str(json['twitterUrl']),
    github: _str(json['githubUrl']),
    portfolio: _str(json['portfolioUrl']),
  );
}

/// A certificate or licence on the profile (`CredentialDto`).
class Credential {
  const Credential({
    required this.id,
    required this.source,
    required this.name,
    this.code,
    this.issuer,
    this.issuedAt,
    this.expiresAt,
    this.expired = false,
    this.status,
    this.credentialUrl,
    this.fileUrl,
    this.fileName,
    this.reviewNote,
    this.certificateId,
    this.href,
  });

  final String id;

  /// `ICR_EXAM`, `ICR_MENTORING` (both issued by ICR, read-only) or `EXTERNAL`.
  final String source;
  final String name;
  final String? code;
  final String? issuer;
  final String? issuedAt;
  final String? expiresAt;
  final bool expired;

  /// `SELF_DECLARED`, `PENDING`, `VERIFIED` or `REJECTED`.
  final String? status;
  final String? credentialUrl;
  final String? fileUrl;
  final String? fileName;
  final String? reviewNote;
  final String? certificateId;

  /// The website page of a credential ICR issued ("/learning/certificates/capital-planning-foundation").
  final String? href;

  bool get editable => source == 'EXTERNAL';

  String get sourceLabel => switch (source) {
    'ICR_EXAM' => 'Issued by ICR',
    'ICR_MENTORING' => 'Earned mentoring',
    _ => 'External credential',
  };

  String? get statusLabel => !editable
      ? null
      : switch (status) {
          'VERIFIED' => 'Verified',
          'PENDING' => 'Certificate on file',
          'SELF_DECLARED' => 'Self-declared',
          'REJECTED' => 'Not accepted',
          _ => null,
        };

  factory Credential.fromJson(Map<String, dynamic> json) => Credential(
    id: json['id'] as String,
    source: json['source'] as String? ?? 'EXTERNAL',
    name: json['name'] as String? ?? '',
    code: _str(json['code']),
    issuer: _str(json['issuer']),
    issuedAt: _str(json['issuedAt']),
    expiresAt: _str(json['expiresAt']),
    expired: json['expired'] == true,
    status: _str(json['status']),
    credentialUrl: _str(json['credentialUrl']),
    fileUrl: _str(json['fileUrl']),
    fileName: _str(json['fileName']),
    reviewNote: _str(json['reviewNote']),
    certificateId: _str(json['certificateId']),
    href: _str(json['href']),
  );
}

/// What a credential form sends (`UpsertCredentialDto`): blanks are left out.
class CredentialDraft {
  const CredentialDraft({
    required this.name,
    this.issuer,
    this.issuedOn,
    this.expiresOn,
    this.credentialUrl,
    this.code,
    this.fileUrl,
    this.fileName,
  });

  final String name;
  final String? issuer;

  /// Calendar days.
  final DateTime? issuedOn;
  final DateTime? expiresOn;
  final String? credentialUrl;
  final String? code;
  final String? fileUrl;
  final String? fileName;

  static String? _t(String? v) => v == null || v.trim().isEmpty ? null : v.trim();

  /// A day as the website sends it: `new Date('YYYY-MM-DD').toISOString()`, midnight UTC.
  static String day(DateTime d) => DateTime.utc(d.year, d.month, d.day).toIso8601String();

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'code': ?_t(code),
    'issuer': ?_t(issuer),
    if (issuedOn != null) 'issuedAt': day(issuedOn!),
    if (expiresOn != null) 'expiresAt': day(expiresOn!),
    'credentialUrl': ?_t(credentialUrl),
    'fileUrl': ?_t(fileUrl),
    'fileName': ?_t(fileName),
  };
}

/// The profile's completeness: a score and what is missing, in the API's words.
class Completeness {
  const Completeness({required this.score, this.missing = const []});

  final int score;
  final List<String> missing;

  factory Completeness.fromJson(Object? json) {
    final m = _map(json);
    return Completeness(score: _int(m['score']) ?? 0, missing: _strings(m['missing']));
  }
}

/// The person's own profile (`GET /users/me/profile`): the account row and the
/// default résumé, which holds the About summary and the skills.
class MyProfile {
  const MyProfile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.profileSlug,
    this.designation,
    this.yearsExperience,
    this.languages = const [],
    this.workEmail,
    this.phone,
    this.phoneVerified = false,
    this.altPhone,
    this.avatarUrl,
    this.coverImage,
    this.companyName,
    this.hasResume = false,
    this.jobTitle,
    this.summary,
    this.skills = const [],
    this.location,
    this.completeness = const Completeness(score: 0),
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String? profileSlug;

  /// The headline under the name ("Facilities Manager").
  final String? designation;
  final int? yearsExperience;
  final List<String> languages;
  final String? workEmail;

  /// E.164 ("+919876543210").
  final String? phone;
  final bool phoneVerified;
  final String? altPhone;
  final String? avatarUrl;

  /// A ready-made cover's id or an uploaded `/uploads/...` image.
  final String? coverImage;

  /// The active company's name.
  final String? companyName;

  /// False for the roles that hold no résumé (staff): About and Skills are not theirs.
  final bool hasResume;
  final String? jobTitle;
  final String? summary;
  final List<String> skills;
  final String? location;
  final Completeness completeness;

  String get fullName {
    final n = '$firstName $lastName'.trim();
    return n.isEmpty ? email : n;
  }

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final both = '$f$l'.toUpperCase();
    return both.isNotEmpty ? both : (email.isNotEmpty ? email[0].toUpperCase() : '?');
  }

  /// The headline the page shows: the designation, else the résumé's title.
  String? get headline => designation ?? jobTitle;

  /// "/members/pooja-professional", the public page.
  String get publicPath => '/members/${profileSlug ?? id}';

  factory MyProfile.fromJson(Map<String, dynamic> json) {
    final user = _map(json['user']);
    final resume = json['resume'] is Map ? _map(json['resume']) : null;
    return MyProfile(
      id: user['id'] as String? ?? '',
      email: user['email'] as String? ?? '',
      firstName: user['firstName'] as String? ?? '',
      lastName: user['lastName'] as String? ?? '',
      role: user['role'] as String? ?? 'PROFESSIONAL',
      profileSlug: _str(user['profileSlug']),
      designation: _str(user['designation']),
      yearsExperience: _int(user['yearsExperience']),
      languages: _strings(user['languages']),
      workEmail: _str(user['workEmail']),
      phone: _str(user['phone']),
      phoneVerified: user['phoneVerified'] == true,
      altPhone: _str(user['altPhone']),
      avatarUrl: _str(user['avatarUrl']),
      coverImage: _str(user['coverImage']),
      companyName: _str(_map(json['company'])['name']),
      hasResume: resume != null,
      jobTitle: _str(resume?['jobTitle']),
      summary: _str(resume?['summary']),
      skills: _strings(resume?['skills']),
      location: _str(resume?['location']),
      completeness: Completeness.fromJson(json['completeness']),
    );
  }
}

/// A file the API took (`POST /uploads`): the `/uploads/...` path to save.
class UploadedFile {
  const UploadedFile({required this.url, required this.name});

  final String url;
  final String name;
}

/// A photo the person chose on their phone, ready to upload.
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.name, this.mimeType});

  final List<int> bytes;
  final String name;

  /// `image/jpeg`, `image/png` or `image/webp`; read from [name] when null.
  final String? mimeType;

  /// Always explicit: the API refuses `application/octet-stream` for these uploads.
  String get contentType {
    if (mimeType != null) return mimeType!;
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }
}

// --- other members ---------------------------------------------------------------------------------------------

/// Followers and following, and whether the viewer follows (`follow` on a member).
class FollowState {
  const FollowState({required this.followers, required this.following, required this.viewerFollows});

  final int followers;
  final int following;
  final bool viewerFollows;

  factory FollowState.fromJson(Object? json) {
    final m = _map(json);
    return FollowState(
      followers: _int(m['followers']) ?? 0,
      following: _int(m['following']) ?? 0,
      viewerFollows: m['viewerFollows'] == true,
    );
  }

  FollowState copyWith({int? followers, bool? viewerFollows}) => FollowState(
    followers: followers ?? this.followers,
    following: following,
    viewerFollows: viewerFollows ?? this.viewerFollows,
  );
}

/// A credential as a public page lists it.
class PublicCredential {
  const PublicCredential({required this.name, this.code, this.issuer, this.issuedAt, this.url, this.verified = false});

  final String name;
  final String? code;
  final String? issuer;
  final String? issuedAt;
  final String? url;
  final bool verified;

  factory PublicCredential.fromJson(Map<String, dynamic> json) => PublicCredential(
    name: json['name'] as String? ?? '',
    code: _str(json['code']),
    issuer: _str(json['issuer']),
    issuedAt: _str(json['issuedAt']),
    url: _str(json['credentialUrl']),
    verified: json['status'] == 'VERIFIED',
  );
}

/// A chapter or council the member is in.
class MemberGroup {
  const MemberGroup({required this.slug, required this.name, this.city});

  final String slug;
  final String name;
  final String? city;

  factory MemberGroup.fromJson(Map<String, dynamic> json) =>
      MemberGroup(slug: json['slug'] as String? ?? '', name: json['name'] as String? ?? '', city: _str(json['city']));
}

/// Another member's public page (`GET /members/:id`; the id or the profile slug).
class MemberProfile {
  const MemberProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profileSlug,
    this.avatarUrl,
    this.coverImage,
    this.headline,
    this.city,
    this.companyName,
    this.companyLogoUrl,
    this.memberSince,
    this.about,
    this.skills = const [],
    this.languages = const [],
    this.yearsExperience,
    this.experience = const [],
    this.careerBreaks = const [],
    this.education = const [],
    this.links = const ProfileLinks(),
    this.credentials = const [],
    this.reputation = 0,
    this.threads = 0,
    this.replies = 0,
    this.acceptedAnswers = 0,
    this.chapters = const [],
    this.councils = const [],
    this.mentorProfileId,
    this.follow = const FollowState(followers: 0, following: 0, viewerFollows: false),
    this.isOwner = false,
    this.signedIn = false,
    this.readyForNextRole = false,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? profileSlug;
  final String? avatarUrl;
  final String? coverImage;

  /// "Facilities Manager · Acme", from the current role.
  final String? headline;
  final String? city;
  final String? companyName;
  final String? companyLogoUrl;
  final String? memberSince;
  final String? about;
  final List<String> skills;
  final List<String> languages;
  final int? yearsExperience;
  final List<Experience> experience;
  final List<CareerBreak> careerBreaks;
  final List<Education> education;
  final ProfileLinks links;
  final List<PublicCredential> credentials;
  final int reputation;
  final int threads;
  final int replies;
  final int acceptedAnswers;
  final List<MemberGroup> chapters;
  final List<MemberGroup> councils;
  final String? mentorProfileId;
  final FollowState follow;

  /// The page is the viewer's own.
  final bool isOwner;

  /// The page was read with a session (`viewer` set).
  final bool signedIn;
  final bool readyForNextRole;

  String get fullName {
    final n = '$firstName $lastName'.trim();
    return n.isEmpty ? 'ICR member' : n;
  }

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final both = '$f$l'.toUpperCase();
    return both.isEmpty ? '?' : both;
  }

  /// "/members/pooja-professional", the page on the website.
  String get sitePath => '/members/${profileSlug ?? id}';

  factory MemberProfile.fromJson(Map<String, dynamic> json) {
    final forum = _map(json['forum']);
    final viewer = json['viewer'] is Map ? _map(json['viewer']) : null;
    final company = _map(json['company']);
    List<Map<String, dynamic>> rows(String key) => [
      for (final r in (json[key] as List? ?? const []))
        if (r is Map) r.cast<String, dynamic>(),
    ];
    return MemberProfile(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      profileSlug: _str(json['profileSlug']),
      avatarUrl: _str(json['avatarUrl']),
      coverImage: _str(json['coverImage']),
      headline: _str(json['headline']),
      city: _str(json['city']),
      companyName: _str(company['name']),
      companyLogoUrl: _str(company['logoUrl']),
      memberSince: _str(json['memberSince']),
      about: _str(json['about']),
      skills: _strings(json['skills']),
      languages: _strings(json['languages']),
      yearsExperience: _int(json['yearsExperience']),
      experience: rows('experience').map(Experience.fromJson).toList(),
      careerBreaks: rows('careerBreaks').map(CareerBreak.fromJson).toList(),
      education: rows('education').map(Education.fromJson).toList(),
      links: ProfileLinks.fromJson(_map(json['links'])),
      credentials: rows('credentials').map(PublicCredential.fromJson).toList(),
      reputation: _int(forum['reputation']) ?? 0,
      threads: _int(forum['threads']) ?? 0,
      replies: _int(forum['replies']) ?? 0,
      acceptedAnswers: _int(forum['acceptedAnswers']) ?? 0,
      chapters: rows('chapters').map(MemberGroup.fromJson).toList(),
      councils: rows('councils').map(MemberGroup.fromJson).toList(),
      mentorProfileId: _str(json['mentorProfileId']),
      follow: FollowState.fromJson(json['follow']),
      isOwner: viewer?['isOwner'] == true,
      signedIn: viewer != null,
      readyForNextRole: json['nextRole'] is Map,
    );
  }

  MemberProfile withFollow(FollowState next) => MemberProfile(
    id: id,
    firstName: firstName,
    lastName: lastName,
    profileSlug: profileSlug,
    avatarUrl: avatarUrl,
    coverImage: coverImage,
    headline: headline,
    city: city,
    companyName: companyName,
    companyLogoUrl: companyLogoUrl,
    memberSince: memberSince,
    about: about,
    skills: skills,
    languages: languages,
    yearsExperience: yearsExperience,
    experience: experience,
    careerBreaks: careerBreaks,
    education: education,
    links: links,
    credentials: credentials,
    reputation: reputation,
    threads: threads,
    replies: replies,
    acceptedAnswers: acceptedAnswers,
    chapters: chapters,
    councils: councils,
    mentorProfileId: mentorProfileId,
    follow: next,
    isOwner: isOwner,
    signedIn: signedIn,
    readyForNextRole: readyForNextRole,
  );
}

/// One of a member's discussions (`ForumThreadCardDto`, the fields a row needs).
class ForumPost {
  const ForumPost({
    required this.id,
    required this.slug,
    required this.title,
    this.excerpt,
    this.category,
    this.replyCount = 0,
    this.viewCount = 0,
    this.createdAt,
    this.lastActivityAt,
    this.answered = false,
  });

  final String id;
  final String slug;
  final String title;
  final String? excerpt;
  final String? category;
  final int replyCount;
  final int viewCount;
  final String? createdAt;
  final String? lastActivityAt;
  final bool answered;

  factory ForumPost.fromJson(Map<String, dynamic> json) => ForumPost(
    id: json['id'] as String,
    slug: json['slug'] as String? ?? json['id'] as String,
    title: json['title'] as String? ?? '',
    excerpt: _str(json['excerpt']),
    category: _str(_map(json['subcategory'])['name']) ?? _str(_map(json['category'])['name']),
    replyCount: _int(json['replyCount']) ?? 0,
    viewCount: _int(json['viewCount']) ?? 0,
    createdAt: _str(json['createdAt']),
    lastActivityAt: _str(json['lastActivityAt']),
    answered: json['hasAcceptedAnswer'] == true,
  );
}

// --- companies -------------------------------------------------------------------------------------------------

/// A company the person is a member of (`MyCompanyDto`).
class MyCompany {
  const MyCompany({
    required this.companyId,
    required this.name,
    required this.role,
    this.logoUrl,
    this.branchName,
    this.active = false,
    this.hasSupplierListing = false,
    this.city,
    this.state,
    this.industry,
    this.verified = false,
    this.joinedAt,
    this.memberCount = 1,
    this.soleAdmin = false,
    this.pendingJoinRequests,
  });

  final String companyId;
  final String name;
  final String role;
  final String? logoUrl;
  final String? branchName;

  /// The company the person is acting for now.
  final bool active;
  final bool hasSupplierListing;
  final String? city;
  final String? state;
  final String? industry;
  final bool verified;
  final String? joinedAt;
  final int memberCount;

  /// The person is its only admin: the API refuses Leave.
  final bool soleAdmin;
  final int? pendingJoinRequests;

  factory MyCompany.fromJson(Map<String, dynamic> json) => MyCompany(
    companyId: json['companyId'] as String,
    name: json['name'] as String? ?? '',
    role: json['role'] as String? ?? 'PROFESSIONAL',
    logoUrl: _str(json['logoUrl']),
    branchName: _str(json['branchName']),
    active: json['active'] == true,
    hasSupplierListing: json['hasSupplierListing'] == true,
    city: _str(json['city']),
    state: _str(json['state']),
    industry: _str(json['industry']),
    verified: json['verified'] == true,
    joinedAt: _str(json['joinedAt']),
    memberCount: _int(json['memberCount']) ?? 1,
    soleAdmin: json['soleAdmin'] == true,
    pendingJoinRequests: _int(json['pendingJoinRequests']),
  );
}

/// A request to join a company, waiting for its admins (`MyJoinRequestDto`).
class JoinRequest {
  const JoinRequest({
    required this.companyId,
    required this.name,
    required this.role,
    this.logoUrl,
    this.note,
    this.requestedAt,
  });

  final String companyId;
  final String name;
  final String role;
  final String? logoUrl;
  final String? note;
  final String? requestedAt;

  factory JoinRequest.fromJson(Map<String, dynamic> json) => JoinRequest(
    companyId: json['companyId'] as String,
    name: json['name'] as String? ?? '',
    role: json['role'] as String? ?? 'PROFESSIONAL',
    logoUrl: _str(json['logoUrl']),
    note: _str(json['note']),
    requestedAt: _str(json['requestedAt']),
  );
}

/// `GET /me/companies`.
class MyCompanies {
  const MyCompanies({
    required this.personalRole,
    this.canJoinCompanies = true,
    this.companies = const [],
    this.requests = const [],
  });

  final String personalRole;

  /// False for ICR staff, whose accounts are personal.
  final bool canJoinCompanies;
  final List<MyCompany> companies;
  final List<JoinRequest> requests;

  /// The company being acted for, or null for the personal account.
  MyCompany? get active {
    for (final c in companies) {
      if (c.active) return c;
    }
    return null;
  }

  factory MyCompanies.fromJson(Map<String, dynamic> json) => MyCompanies(
    personalRole: json['personalRole'] as String? ?? 'PROFESSIONAL',
    canJoinCompanies: json['canJoinCompanies'] != false,
    companies: [
      for (final c in (json['companies'] as List? ?? const []))
        if (c is Map) MyCompany.fromJson(c.cast<String, dynamic>()),
    ],
    requests: [
      for (final r in (json['requests'] as List? ?? const []))
        if (r is Map) JoinRequest.fromJson(r.cast<String, dynamic>()),
    ],
  );

  MyCompanies copyWith({List<MyCompany>? companies, List<JoinRequest>? requests}) => MyCompanies(
    personalRole: personalRole,
    canJoinCompanies: canJoinCompanies,
    companies: companies ?? this.companies,
    requests: requests ?? this.requests,
  );
}

/// A fresh token pair the API handed back (switch, create, leave), with the person as they now are.
class SessionTokens {
  const SessionTokens({required this.accessToken, required this.refreshToken, this.user});

  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic>? user;

  factory SessionTokens.fromJson(Map<String, dynamic> json) => SessionTokens(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    user: json['user'] is Map ? _map(json['user']) : null,
  );
}

/// The one-screen "Create a company page" form (`CreateMyCompanyDto`).
class CompanyDraft {
  const CompanyDraft({
    required this.name,
    required this.industry,
    required this.size,
    required this.legalStructure,
    required this.city,
    this.state,
    this.legalName,
    this.website,
    this.description,
    this.logoUrl,
  });

  final String name;
  final String industry;
  final String size;
  final String legalStructure;
  final String city;
  final String? state;
  final String? legalName;
  final String? website;

  /// The tagline.
  final String? description;
  final String? logoUrl;

  static String? _t(String? v) => v == null || v.trim().isEmpty ? null : v.trim();

  /// The body: optional keys left out when blank, never `""` (`@IsUrl` and `@IsIn` refuse it).
  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'legalName': ?_t(legalName),
    'website': ?_t(website),
    'industry': industry,
    'size': size,
    'legalStructure': legalStructure,
    'city': city,
    'state': ?_t(state),
    'description': ?_t(description),
    'logoUrl': ?_t(logoUrl),
  };
}

/// A company already on ICR that looks like the one being created (`CompanyLookalikeDto`).
class CompanyLookalike {
  const CompanyLookalike({
    required this.id,
    required this.name,
    this.logoUrl,
    this.city,
    this.state,
    this.industry,
    this.reason,
  });

  final String id;
  final String name;
  final String? logoUrl;
  final String? city;
  final String? state;
  final String? industry;

  /// `name`, `website` or `colleagues`.
  final String? reason;

  String get reasonLabel => switch (reason) {
    'website' => 'Same website',
    'colleagues' => 'People from your email domain work here',
    _ => 'Similar name',
  };

  factory CompanyLookalike.fromJson(Map<String, dynamic> json) => CompanyLookalike(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    logoUrl: _str(json['logoUrl']),
    city: _str(json['city']),
    state: _str(json['state']),
    industry: _str(json['industry']),
    reason: _str(json['reason']),
  );
}

// --- settings --------------------------------------------------------------------------------------------------

/// One row of the notification preferences (`GET /notifications/preferences`).
class NotificationPreference {
  const NotificationPreference({required this.category, required this.inApp, required this.email, this.locked = false});

  final String category;
  final bool inApp;
  final bool email;

  /// Always sent (payments, support, security): the switches are drawn on and disabled.
  final bool locked;

  factory NotificationPreference.fromJson(Map<String, dynamic> json) => NotificationPreference(
    category: json['category'] as String,
    inApp: json['inApp'] != false,
    email: json['email'] != false,
    locked: json['locked'] == true,
  );

  NotificationPreference copyWith({bool? inApp, bool? email}) =>
      NotificationPreference(category: category, inApp: inApp ?? this.inApp, email: email ?? this.email, locked: locked);
}
