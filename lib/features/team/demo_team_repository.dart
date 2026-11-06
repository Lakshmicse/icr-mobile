import 'dart:async';

import '../../core/api/api_error.dart';
import 'team_models.dart';
import 'team_repository.dart';

/// The Team page with no API: a sample company team kept in memory, so changes stick for the session. It behaves as
/// the API does where the screen depends on it (a request leaves the list once decided, an add shows as pending,
/// an address already on the team is reported as such).
///
/// Tests use it as their stand-in: every call is logged in [calls], a call can be made to fail through [failures]
/// (by name, or `name:arg`), the last body of each write is in [sent], and [gate] holds calls to show loading.
class DemoTeamRepository implements TeamRepository {
  DemoTeamRepository({
    List<TeamMember>? members,
    List<TeamRequest>? requests,
    List<PendingAdd>? adds,
    List<TeamInvite>? invites,
    List<Office>? offices,
    List<TeamPerson>? people,
  }) : membersNow = [...(members ?? demoTeamMembers)],
       requestsNow = [...(requests ?? demoTeamRequests)],
       addsNow = [...(adds ?? demoPendingAdds)],
       invitesNow = [...(invites ?? demoTeamInvites)],
       officesNow = [...(offices ?? demoOffices)],
       peopleNow = [...(people ?? demoPeople)];

  List<TeamMember> membersNow;
  List<TeamRequest> requestsNow;
  List<PendingAdd> addsNow;
  List<TeamInvite> invitesNow;
  List<Office> officesNow;
  List<TeamPerson> peopleNow;

  /// What `lookup` answers per address; an address not here is "not on ICR".
  final lookups = <String, TeamLookup>{};

  Future<void>? gate;
  final calls = <String>[];
  final failures = <String, Object>{};
  final sent = <String, Object?>{};

  int count(String name) => calls.where((c) => c == name || c.startsWith('$name:')).length;

  Future<void> _enter(String name, [String? arg]) async {
    calls.add(arg == null ? name : '$name:$arg');
    if (gate != null) await gate;
    final failure = failures[arg == null ? name : '$name:$arg'] ?? failures[name];
    if (failure != null) throw failure is ApiError ? failure : ApiError(failure.toString(), statusCode: 400);
  }

  @override
  Future<List<TeamMember>> members() async {
    await _enter('members');
    return [...membersNow];
  }

  @override
  Future<List<TeamRequest>> requests() async {
    await _enter('requests');
    return [...requestsNow];
  }

  @override
  Future<List<PendingAdd>> pendingAdds() async {
    await _enter('pendingAdds');
    return [...addsNow];
  }

  @override
  Future<List<TeamInvite>> invites() async {
    await _enter('invites');
    return [...invitesNow];
  }

  @override
  Future<List<Office>> offices(String companyId) async {
    await _enter('offices');
    return [...officesNow];
  }

  Office? _office(String? id) {
    for (final o in officesNow) {
      if (o.id == id) return o;
    }
    return null;
  }

  @override
  Future<void> approve(String userId, {required String role, String? branchId}) async {
    await _enter('approve', userId);
    sent['approve'] = {'userId': userId, 'role': role, 'branchId': branchId};
    final request = requestsNow.firstWhere(
      (r) => r.userId == userId,
      orElse: () => throw ApiError('That request is no longer waiting.', statusCode: 404),
    );
    requestsNow = [
      for (final r in requestsNow)
        if (r.userId != userId) r,
    ];
    membersNow = [
      ...membersNow,
      TeamMember(
        id: userId,
        email: '${request.firstName.toLowerCase()}@example.com',
        firstName: request.firstName,
        lastName: request.lastName,
        role: role,
        branchId: _office(branchId)?.id,
        branchName: _office(branchId)?.name,
      ),
    ];
  }

  @override
  Future<void> decline(String userId) async {
    await _enter('decline', userId);
    requestsNow = [
      for (final r in requestsNow)
        if (r.userId != userId) r,
    ];
  }

  @override
  Future<void> cancelAdd(String userId) async {
    await _enter('cancelAdd', userId);
    addsNow = [
      for (final a in addsNow)
        if (a.userId != userId) a,
    ];
  }

  @override
  Future<void> revokeInvite(String id) async {
    await _enter('revokeInvite', id);
    invitesNow = [
      for (final i in invitesNow)
        if (i.id != id) i,
    ];
  }

  @override
  Future<void> updateMember(String id, Map<String, Object?> patch) async {
    await _enter('updateMember', id);
    sent['updateMember'] = {'id': id, ...patch};
    membersNow = [
      for (final m in membersNow)
        if (m.id != id)
          m
        else
          TeamMember(
            id: m.id,
            email: m.email,
            firstName: m.firstName,
            lastName: m.lastName,
            role: patch['role'] as String? ?? m.role,
            learningRoles: patch.containsKey('learningRoles')
                ? [for (final r in patch['learningRoles'] as List? ?? const []) '$r']
                : m.learningRoles,
            handlesTopics: m.handlesTopics,
            branchId: patch.containsKey('branchId') ? _office(patch['branchId'] as String?)?.id : m.branchId,
            branchName: patch.containsKey('branchId') ? _office(patch['branchId'] as String?)?.name : m.branchName,
            isActive: m.isActive,
          ),
    ];
  }

  @override
  Future<void> removeMember(String id) async {
    await _enter('removeMember', id);
    membersNow = [
      for (final m in membersNow)
        if (m.id != id) m,
    ];
  }

  @override
  Future<List<TeamPerson>> findPeople(String search) async {
    await _enter('findPeople', search);
    final q = search.trim().toLowerCase();
    return [
      for (final p in peopleNow)
        if (p.name.toLowerCase().contains(q)) p,
    ];
  }

  @override
  Future<void> addMember({
    required String userId,
    required String role,
    String? branchId,
    List<String> learningRoles = const [],
  }) async {
    await _enter('addMember', userId);
    sent['addMember'] = {
      'userId': userId,
      'role': role,
      'branchId': branchId,
      if (learningRoles.isNotEmpty) 'learningRoles': learningRoles,
    };
    final person = peopleNow.firstWhere(
      (p) => p.id == userId,
      orElse: () => throw ApiError('That person is not on ICR, or their profile is private.', statusCode: 404),
    );
    addsNow = [
      ...addsNow,
      PendingAdd(
        id: 'add-$userId',
        userId: userId,
        firstName: person.firstName,
        lastName: person.lastName,
        role: role,
        learningRoles: learningRoles,
        branchName: _office(branchId)?.name,
        invitedBy: 'Asha Rao',
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<TeamLookup> lookup(String email) async {
    await _enter('lookup', email.trim().toLowerCase());
    return lookups[email.trim().toLowerCase()] ?? const TeamLookup();
  }

  @override
  Future<void> invite({
    required String email,
    required String role,
    String? branchId,
    List<String> learningRoles = const [],
  }) async {
    await _enter('invite', email.trim());
    sent['invite'] = {
      'email': email.trim(),
      'role': role,
      'branchId': branchId,
      if (learningRoles.isNotEmpty) 'learningRoles': learningRoles,
    };
    invitesNow = [
      ...invitesNow,
      TeamInvite(
        id: 'inv-${invitesNow.length + 1}',
        email: email.trim(),
        role: role,
        learningRoles: learningRoles,
        branchName: _office(branchId)?.name,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      ),
    ];
  }
}

// --- the sample team ---------------------------------------------------------------------------------------------

const demoTeamMembers = <TeamMember>[
  TeamMember(
    id: 'u-asha',
    email: 'asha@techcorp.example',
    firstName: 'Asha',
    lastName: 'Rao',
    role: 'COMPANY_ADMIN',
    handlesTopics: ['SALES', 'PROCUREMENT', 'CAREERS', 'PARTNERSHIP', 'GENERAL'],
  ),
  TeamMember(
    id: 'u-bina',
    email: 'bina@techcorp.example',
    firstName: 'Bina',
    lastName: 'Shah',
    role: 'BRANCH_ADMIN',
    handlesTopics: ['CAREERS'],
    branchId: 'b-hq',
    branchName: 'Head Office',
  ),
  TeamMember(
    id: 'u-rahul',
    email: 'rahul@techcorp.example',
    firstName: 'Rahul',
    lastName: 'Menon',
    role: 'RECRUITER',
    handlesTopics: ['CAREERS'],
    branchId: 'b-hq',
    branchName: 'Head Office',
  ),
  TeamMember(
    id: 'u-vivek',
    email: 'vivek@techcorp.example',
    firstName: 'Vivek',
    lastName: 'Nair',
    role: 'VENDOR',
    handlesTopics: ['SALES', 'PROCUREMENT'],
  ),
  TeamMember(
    id: 'u-hema',
    email: 'hema@techcorp.example',
    firstName: 'Hema',
    lastName: 'Iyer',
    role: 'HIRING_MANAGER',
    branchId: 'b-hq',
    branchName: 'Head Office',
  ),
  TeamMember(
    id: 'u-dev',
    email: 'dev@techcorp.example',
    firstName: 'Dev',
    lastName: 'Kapoor',
    role: 'RECRUITER',
    isActive: false,
  ),
];

final demoTeamRequests = <TeamRequest>[
  TeamRequest(
    id: 'req-pooja',
    userId: 'u-pooja',
    firstName: 'Pooja',
    lastName: 'Pillai',
    role: 'PROFESSIONAL',
    note: 'I run facilities at your Pune site.',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
];

final demoPendingAdds = <PendingAdd>[
  PendingAdd(
    id: 'add-kiran',
    userId: 'u-kiran',
    firstName: 'Kiran',
    lastName: 'Bose',
    role: 'RECRUITER',
    branchName: 'Head Office',
    invitedBy: 'Asha Rao',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
];

final demoTeamInvites = <TeamInvite>[
  TeamInvite(
    id: 'inv-1',
    email: 'hr@partner.example',
    role: 'HIRING_MANAGER',
    branchName: 'Head Office',
    expiresAt: DateTime.now().add(const Duration(days: 5)),
  ),
];

const demoOffices = <Office>[
  Office(id: 'b-hq', name: 'Head Office'),
  Office(id: 'b-tower', name: 'Tower A', parentId: 'b-hq', depth: 1),
  Office(id: 'b-pune', name: 'Pune Campus'),
];

const demoPeople = <TeamPerson>[
  TeamPerson(id: 'u-meera', firstName: 'Meera', lastName: 'Joshi', headline: 'Facilities manager'),
  TeamPerson(id: 'u-meena', firstName: 'Meena', lastName: 'Kulkarni'),
];
