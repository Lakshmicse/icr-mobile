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
  );
}
