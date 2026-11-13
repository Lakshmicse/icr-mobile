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
    this.permissions = const [],
    this.scopedPermissions = const [],
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

  /// The staff permission keys the person was given through a role (`UserDto.permissions`: `chapters:manage`,
  /// `councils:manage`, `events:manage`…). A Super Admin holds every key without any being listed: ask
  /// [holdsPermission], never this list.
  final List<String> permissions;

  /// Of [permissions], the keys held only over some chapters, councils or institutes (`UserDto.scopedPermissions`):
  /// such a grant edits those records and cannot create or retire one.
  final List<String> scopedPermissions;

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
    permissions: [for (final k in (json['permissions'] as List? ?? const [])) '$k'],
    scopedPermissions: [for (final k in (json['scopedPermissions'] as List? ?? const [])) '$k'],
  );
}

/// Whether the person may use what a staff permission key opens: the website's `hasPermission`. A Super Admin
/// holds every key; anyone else holds the ones a role gave them (Chapters Admin, Councils Admin, Events Admin,
/// Community Manager…), which a Super Admin assigns on the website's Roles page.
bool holdsPermission(SessionUser? user, String key) =>
    user != null && (user.role == 'SUPER_ADMIN' || user.permissions.contains(key));

/// Whether the key is held over every record, not only some chapters or councils: the website's
/// `hasPermissionEverywhere`. Creating and retiring a record need this; the API refuses them otherwise.
bool holdsPermissionEverywhere(SessionUser? user, String key) =>
    user != null &&
    (user.role == 'SUPER_ADMIN' || (user.permissions.contains(key) && !user.scopedPermissions.contains(key)));

/// Whether the recruitment pitch ("Become an ICR Mentor", "Apply as Mentor") is for this person: the website's
/// `canOfferToMentor`. A visitor, yes; a member only when they never applied (no mentor profile in any state),
/// mentor nobody, and are not ICR staff. A mentor, an applicant or a staffer would be pitched something they
/// already have or cannot have.
bool canOfferToMentor(SessionUser? user) =>
    user == null || (user.role != 'SUPER_ADMIN' && user.mentorStatus == null && !user.mentorsSomeone);
