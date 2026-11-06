import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import 'api_team_repository.dart';
import 'demo_team_repository.dart';
import 'team_models.dart';

/// Where the Team page reads and writes: the API, or sample data for design review. Every refusal comes out as an
/// `ApiError` carrying the API's own sentence (a full team, an office a role needs).
abstract class TeamRepository {
  /// `GET /team/members`: the active members, and the deactivated ones the API still lists.
  Future<List<TeamMember>> members();

  /// `GET /team/requests`: people waiting for an admin to decide.
  Future<List<TeamRequest>> requests();

  /// `GET /team/invitations`: people an admin added from ICR who have not answered.
  Future<List<PendingAdd>> pendingAdds();

  /// `GET /team/invites`: email invites nobody has accepted or revoked.
  Future<List<TeamInvite>> invites();

  /// `GET /branches?companyId=`: the company's offices, parents before their children.
  Future<List<Office>> offices(String companyId);

  /// `POST /team/requests/:userId/approve`: the admin names the role and, optionally, the office.
  Future<void> approve(String userId, {required String role, String? branchId});

  /// `POST /team/requests/:userId/decline`.
  Future<void> decline(String userId);

  /// `DELETE /team/invitations/:userId`: takes a pending add back and frees its seat.
  Future<void> cancelAdd(String userId);

  /// `DELETE /team/invites/:id`.
  Future<void> revokeInvite(String id);

  /// `PATCH /team/members/:id` with only the fields given (`role`, `branchId`; a null `branchId` clears the office).
  Future<void> updateMember(String id, Map<String, Object?> patch);

  /// `DELETE /team/members/:id`: ends their place at the company; their ICR account stays theirs.
  Future<void> removeMember(String id);

  /// `GET /team/people?search=`: members with a public profile whose name matches, ten at most.
  Future<List<TeamPerson>> findPeople(String search);

  /// `POST /team/members`: asks someone already on ICR; they join once they accept. [learningRoles] ride along at a
  /// learning-partner company (a Member needs at least one).
  Future<void> addMember({
    required String userId,
    required String role,
    String? branchId,
    List<String> learningRoles = const [],
  });

  /// `GET /team/lookup?email=`: whether the address is on ICR (company admins only).
  Future<TeamLookup> lookup(String email);

  /// `POST /team/invites`: an email invite, with [learningRoles] at a learning-partner company.
  Future<void> invite({
    required String email,
    required String role,
    String? branchId,
    List<String> learningRoles = const [],
  });
}

/// The team calls for this screen: the API through the app's client, or the sample team in demo mode
/// (`FEED_SOURCE=demo`).
TeamRepository teamRepositoryOf(BuildContext context) =>
    AppConfig.demo ? DemoTeamRepository() : ApiTeamRepository(api: Provider.of<ApiClient>(context, listen: false));
