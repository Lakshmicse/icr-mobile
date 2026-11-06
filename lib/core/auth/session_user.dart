/// The signed-in person, from `UserDto` (`GET /auth/me`, and the login response).
class SessionUser {
  const SessionUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.avatarUrl,
    this.emailVerified = false,
    this.companyId,
    this.mentorStatus,
    this.mentorsSomeone = false,
    this.learningRoles = const [],
    this.learningPartner = false,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String? avatarUrl;
  final bool emailVerified;

  /// The company the person is acting for; null when acting as themselves.
  final String? companyId;

  /// The person's mentor profile, in whatever state (DRAFT, PENDING, APPROVED, PAUSED, REJECTED); null when they
  /// never applied.
  final String? mentorStatus;

  /// Whether anyone is being mentored by them right now, listed or not.
  final bool mentorsSomeone;

  /// The learning roles (Course Admin, Trainer…) the person holds at the company they act for, given only while
  /// that company runs a partner institute (`UserDto.learningRoles`): the Partner Institute row is theirs.
  final List<String> learningRoles;

  /// The company the person acts for is a learning partner ICR approved (`UserDto.learningPartner`): its admin may
  /// give learning roles on the team page.
  final bool learningPartner;

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0] : '';
    final last = lastName.isNotEmpty ? lastName[0] : '';
    final both = '$first$last'.toUpperCase();
    return both.isEmpty ? '?' : both;
  }

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
    id: json['id'] as String,
    email: json['email'] as String? ?? '',
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
    role: json['role'] as String? ?? 'PROFESSIONAL',
    avatarUrl: json['avatarUrl'] as String?,
    emailVerified: json['emailVerified'] == true,
    companyId: json['companyId'] as String?,
    mentorStatus: json['mentorStatus'] as String?,
    mentorsSomeone: json['mentorsSomeone'] == true,
    learningRoles: [for (final r in (json['learningRoles'] as List? ?? const [])) '$r'],
    learningPartner: json['learningPartner'] == true,
  );
}

/// Whether the recruitment pitch ("Become an ICR Mentor", "Apply as Mentor") is for this person: the website's
/// `canOfferToMentor`. A visitor, yes; a member only when they never applied (no mentor profile in any state),
/// mentor nobody, and are not ICR staff. A mentor, an applicant or a staffer would be pitched something they
/// already have or cannot have.
bool canOfferToMentor(SessionUser? user) =>
    user == null || (user.role != 'SUPER_ADMIN' && user.mentorStatus == null && !user.mentorsSomeone);
