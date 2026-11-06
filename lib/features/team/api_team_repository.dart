import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import 'team_models.dart';
import 'team_repository.dart';

/// The Team page against the ICR API, through the signed-in client.
class ApiTeamRepository implements TeamRepository {
  ApiTeamRepository({required this.api});

  final ApiClient api;

  Future<T> _call<T>(Future<T> Function(Dio dio) body) async {
    try {
      return await body(api.dio);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<List<Map<String, dynamic>>> _list(String path, [Map<String, dynamic>? query]) => _call((dio) async {
    final data = (await dio.get<dynamic>(path, queryParameters: query)).data;
    final rows = data is List ? data : (data is Map ? data['data'] as List? : null) ?? const [];
    return [
      for (final r in rows)
        if (r is Map) r.cast<String, dynamic>(),
    ];
  });

  @override
  Future<List<TeamMember>> members() async => (await _list('/team/members')).map(TeamMember.fromJson).toList();

  @override
  Future<List<TeamRequest>> requests() async => (await _list('/team/requests')).map(TeamRequest.fromJson).toList();

  @override
  Future<List<PendingAdd>> pendingAdds() async => (await _list('/team/invitations')).map(PendingAdd.fromJson).toList();

  @override
  Future<List<TeamInvite>> invites() async => (await _list('/team/invites')).map(TeamInvite.fromJson).toList();

  @override
  Future<List<Office>> offices(String companyId) async =>
      Office.tree(await _list('/branches', {'companyId': companyId}));

  @override
  Future<void> approve(String userId, {required String role, String? branchId}) => _call(
    (dio) => dio.post<void>(
      '/team/requests/${Uri.encodeComponent(userId)}/approve',
      data: {'role': role, if (branchId != null && branchId.isNotEmpty) 'branchId': branchId},
    ),
  );

  @override
  Future<void> decline(String userId) =>
      _call((dio) => dio.post<void>('/team/requests/${Uri.encodeComponent(userId)}/decline'));

  @override
  Future<void> cancelAdd(String userId) =>
      _call((dio) => dio.delete<void>('/team/invitations/${Uri.encodeComponent(userId)}'));

  @override
  Future<void> revokeInvite(String id) => _call((dio) => dio.delete<void>('/team/invites/${Uri.encodeComponent(id)}'));

  @override
  Future<void> updateMember(String id, Map<String, Object?> patch) =>
      _call((dio) => dio.patch<void>('/team/members/${Uri.encodeComponent(id)}', data: patch));

  @override
  Future<void> removeMember(String id) => _call((dio) => dio.delete<void>('/team/members/${Uri.encodeComponent(id)}'));

  @override
  Future<List<TeamPerson>> findPeople(String search) async =>
      (await _list('/team/people', {'search': search.trim()})).map(TeamPerson.fromJson).toList();

  @override
  Future<void> addMember({
    required String userId,
    required String role,
    String? branchId,
    List<String> learningRoles = const [],
  }) => _call(
    (dio) => dio.post<void>(
      '/team/members',
      data: {
        'userId': userId,
        'role': role,
        if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
        if (learningRoles.isNotEmpty) 'learningRoles': learningRoles,
      },
    ),
  );

  @override
  Future<TeamLookup> lookup(String email) => _call(
    (dio) async => TeamLookup.fromJson(
      (await dio.get<Map<String, dynamic>>(
            '/team/lookup',
            queryParameters: {'email': email.trim().toLowerCase()},
          )).data ??
          const {},
    ),
  );

  @override
  Future<void> invite({
    required String email,
    required String role,
    String? branchId,
    List<String> learningRoles = const [],
  }) => _call(
    (dio) => dio.post<void>(
      '/team/invites',
      data: {
        'email': email.trim(),
        'role': role,
        if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
        if (learningRoles.isNotEmpty) 'learningRoles': learningRoles,
      },
    ),
  );
}
