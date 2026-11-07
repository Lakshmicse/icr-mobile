/// What the Team screen reads and sends (`/team/*`, `/branches`): a company's members, the people waiting to join,
/// the people it added from ICR that have not answered, its open email invites, its offices, and the viewer's own
/// standing (who they are decides what the page lets them do).
library;

import '../account/account_labels.dart';

String? _str(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

List<String> _strings(Object? v) => [
  for (final s in (v is List ? v : const []))
    if (s is String && s.isNotEmpty) s,
];

Map<String, dynamic> _map(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// `LEARNING_STAFF_ROLE_LABELS`.
const learningStaffRoleLabels = {
  'COURSE_ADMIN': 'Course Admin',
  'BATCH_ADMIN': 'Batch Admin',
  'ENROLMENT_ADMIN': 'Enrolment Admin',
  'TRAINER': 'Trainer',
  'FINANCE': 'Finance',
};

String learningRoleLabel(String role) => learningStaffRoleLabels[role] ?? role;

/// `MESSAGE_TOPIC_LABELS` (the company inbox's topics).
const messageTopicLabels = {
  'SALES': 'Sales & quotes',
  'PROCUREMENT': 'Requirements & buying',
  'CAREERS': 'Careers',
  'PARTNERSHIP': 'Partnerships',
  'GENERAL': 'General',
};

/// How many topics there are, so "all of them" can be said as "All topics".
const messageTopicCount = 5;

/// The role as the team page words it: a learning-only member reads "Member", not "Professional".
String teamRoleLabel(String role, List<String> learningRoles) =>
    role == 'PROFESSIONAL' && learningRoles.isNotEmpty ? 'Member' : roleLabel(role);

/// The name on a row: first and last, trimmed.
String teamPersonName(String first, String last) => '$first $last'.trim();

String teamInitials(String first, String last) {
  final a = first.isNotEmpty ? first[0] : '';
  final b = last.isNotEmpty ? last[0] : '';
  final both = '$a$b'.toUpperCase();
  return both.isEmpty ? '?' : both;
}

/// One active (or deactivated) member of the company (`TeamMemberDto`).
class TeamMember {
  const TeamMember({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.learningRoles = const [],
    this.handlesTopics = const [],
    this.branchId,
    this.branchName,
    this.isActive = true,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final List<String> learningRoles;

  /// Every inbox topic they answer: the role's own and any an admin granted.
  final List<String> handlesTopics;
  final String? branchId;
  final String? branchName;
  final bool isActive;

  String get name => teamPersonName(firstName, lastName);

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
    id: json['id'] as String,
    email: json['email'] as String? ?? '',
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
    role: json['role'] as String? ?? 'PROFESSIONAL',
    learningRoles: _strings(json['learningRoles']),
    handlesTopics: _strings(json['handlesTopics']),
    branchId: _str(json['branchId']),
    branchName: _str(_map(json['branch'])['name']),
    isActive: json['isActive'] != false,
  );
}

/// Someone who asked to join the company, waiting for an admin (`JoinRequestDto`).
class TeamRequest {
  const TeamRequest({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.note,
    this.avatarUrl,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String firstName;
  final String lastName;

  /// The role they asked for; the admin names the real one.
  final String role;
  final String? note;
  final String? avatarUrl;
  final DateTime? createdAt;

  String get name => teamPersonName(firstName, lastName);

  factory TeamRequest.fromJson(Map<String, dynamic> json) {
    final user = _map(json['user']);
    return TeamRequest(
      id: json['id'] as String? ?? '',
      userId: user['id'] as String? ?? '',
      firstName: user['firstName'] as String? ?? '',
      lastName: user['lastName'] as String? ?? '',
      role: json['role'] as String? ?? 'PROFESSIONAL',
      note: _str(json['note']),
      avatarUrl: _str(user['avatarUrl']),
      createdAt: _date(json['createdAt']),
    );
  }
}

/// Someone an admin added from ICR who has not answered yet (`TeamPendingAddDto`). It holds a seat until they do.
class PendingAdd {
  const PendingAdd({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.learningRoles = const [],
    this.branchName,
    this.avatarUrl,
    this.invitedBy,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String role;
  final List<String> learningRoles;
  final String? branchName;
  final String? avatarUrl;

  /// "First Last" of the admin who added them, when still on ICR.
  final String? invitedBy;
  final DateTime? createdAt;

  String get name => teamPersonName(firstName, lastName);

  factory PendingAdd.fromJson(Map<String, dynamic> json) {
    final user = _map(json['user']);
    final by = _map(json['invitedBy']);
    final byName = teamPersonName(by['firstName'] as String? ?? '', by['lastName'] as String? ?? '');
    return PendingAdd(
      id: json['id'] as String? ?? '',
      userId: user['id'] as String? ?? '',
      firstName: user['firstName'] as String? ?? '',
      lastName: user['lastName'] as String? ?? '',
      role: json['role'] as String? ?? 'PROFESSIONAL',
      learningRoles: _strings(json['learningRoles']),
      branchName: _str(_map(json['branch'])['name']),
      avatarUrl: _str(user['avatarUrl']),
      invitedBy: byName.isEmpty ? null : byName,
      createdAt: _date(json['createdAt']),
    );
  }
}

/// An email invite that nobody has accepted or revoked (`TeamInviteDto`).
class TeamInvite {
  const TeamInvite({
    required this.id,
    required this.email,
    required this.role,
    this.learningRoles = const [],
    this.branchName,
    this.expiresAt,
  });

  final String id;
  final String email;
  final String role;
  final List<String> learningRoles;
  final String? branchName;
  final DateTime? expiresAt;

  factory TeamInvite.fromJson(Map<String, dynamic> json) => TeamInvite(
    id: json['id'] as String,
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'PROFESSIONAL',
    learningRoles: _strings(json['learningRoles']),
    branchName: _str(_map(json['branch'])['name']),
    expiresAt: _date(json['expiresAt']),
  );
}

/// A person found by name to add to the team (`GET /team/people`); never carries an email address.
class TeamPerson {
  const TeamPerson({required this.id, required this.firstName, required this.lastName, this.avatarUrl, this.headline});

  final String id;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String? headline;

  String get name => teamPersonName(firstName, lastName);

  factory TeamPerson.fromJson(Map<String, dynamic> json) => TeamPerson(
    id: json['id'] as String,
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
    avatarUrl: _str(json['avatarUrl']),
    headline: _str(json['headline']),
  );
}

/// What `GET /team/lookup?email=` says about an address while an admin invites (`TeamLookupDto`).
class TeamLookup {
  const TeamLookup({
    this.onIcr = false,
    this.person,
    this.alreadyMember = false,
    this.pendingInvite = false,
    this.pendingAdd = false,
  });

  final bool onIcr;

  /// Set only when the address belongs to someone with a public profile (who can be asked in the app).
  final TeamPerson? person;
  final bool alreadyMember;
  final bool pendingInvite;

  /// Already added by an admin and waiting for them to accept.
  final bool pendingAdd;

  factory TeamLookup.fromJson(Map<String, dynamic> json) => TeamLookup(
    onIcr: json['onIcr'] == true,
    person: json['person'] is Map ? TeamPerson.fromJson(_map(json['person'])) : null,
    alreadyMember: json['alreadyMember'] == true,
    pendingInvite: json['pendingInvite'] == true,
    pendingAdd: json['pendingAdd'] == true,
  );
}

/// An office of the company (a `Branch`), or the "Company-wide" choice (an empty [id]).
class Office {
  const Office({required this.id, required this.name, this.parentId, this.depth = 0});

  /// "No office": the member covers the whole company.
  static const companyWide = Office(id: '', name: 'Company-wide');

  final String id;
  final String name;
  final String? parentId;

  /// How deep it sits under the company's head office tree, for indenting the picker.
  final int depth;

  @override
  bool operator ==(Object other) => other is Office && other.id == id;

  @override
  int get hashCode => id.hashCode;

  /// The offices the API listed, parents before their children, each with its depth. Retired offices
  /// (`status` other than ACTIVE, or deleted) are left out, as the website's pickers do.
  static List<Office> tree(List<Map<String, dynamic>> rows) {
    final live = [
      for (final r in rows)
        if (r['id'] is String && r['deletedAt'] == null && (r['status'] ?? 'ACTIVE') == 'ACTIVE') r,
    ];
    final ids = {for (final r in live) r['id'] as String};
    final children = <String?, List<Map<String, dynamic>>>{};
    for (final r in live) {
      final parent = r['parentId'] as String?;
      // An office whose parent is retired is shown at the top rather than lost.
      children.putIfAbsent(parent != null && ids.contains(parent) ? parent : null, () => []).add(r);
    }
    final out = <Office>[];
    void walk(String? parent, int depth) {
      for (final r in children[parent] ?? const <Map<String, dynamic>>[]) {
        out.add(Office(id: r['id'] as String, name: r['name'] as String? ?? '', parentId: parent, depth: depth));
        walk(r['id'] as String, depth + 1);
      }
    }

    walk(null, 0);
    return out;
  }
}

/// Everything the page shows, read together.
class TeamLists {
  const TeamLists({
    this.members = const [],
    this.requests = const [],
    this.adds = const [],
    this.invites = const [],
    this.offices = const [],
  });

  final List<TeamMember> members;
  final List<TeamRequest> requests;
  final List<PendingAdd> adds;
  final List<TeamInvite> invites;
  final List<Office> offices;
}
