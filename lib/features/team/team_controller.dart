import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'team_models.dart';
import 'team_repository.dart';
import 'team_rules.dart';

/// The Team page: the five lists it reads together (members, requests, pending adds, open invites, offices) and the
/// things an admin does to them. The website's `TeamPanel`.
///
/// Every write goes to the API, then every list is read again (the website invalidates its whole `team` cache for
/// the same reason: an approval changes the members, the requests and the seats at once). A refusal comes back as
/// the API's own sentence, either to the caller (a sheet keeps what was typed and shows it) or, for a row's own
/// button, in [actionError] above the lists.
class TeamController extends ChangeNotifier {
  TeamController({required this.repository, required this.viewer});

  final TeamRepository repository;
  final TeamViewer viewer;

  TeamLists data = const TeamLists();

  /// The first read, or a Retry, is in flight and there is nothing to show yet.
  bool loading = true;

  /// Whether a read has ever finished (an empty team is a state; "not read yet" is not).
  bool loaded = false;

  /// Why the lists could not be read (shown with Retry when there is nothing to show).
  String? loadError;

  /// What the last row action was refused with, shown above the lists.
  String? actionError;

  /// The row being worked on, as `action:id` (`approve:u1`, `remove:u2`); one at a time.
  String? busyKey;

  bool _disposed = false;

  bool get busy => busyKey != null;

  /// What the Pending tab counts: people added from ICR plus open email invites.
  int get pendingCount => data.adds.length + data.invites.length;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // --- reading -----------------------------------------------------------------------------------------------

  /// Reads every list. [refresh] keeps what is on screen while it loads (pull to refresh, or after a write);
  /// otherwise the screen shows its loading state.
  Future<void> load({bool refresh = false}) async {
    if (!viewer.hasCompany || !viewer.reachesPage) {
      loading = false;
      _notify();
      return;
    }
    if (!refresh) {
      loading = true;
      loadError = null;
      _notify();
    }
    try {
      final companyId = viewer.companyId!;
      final results = await Future.wait<Object>([
        repository.members(),
        repository.requests(),
        repository.pendingAdds(),
        repository.invites(),
        // Offices only fill a picker: a company with none, or an answer that fails, still has a team page.
        repository.offices(companyId).catchError((Object _) => const <Office>[]),
      ]);
      data = TeamLists(
        members: results[0] as List<TeamMember>,
        requests: results[1] as List<TeamRequest>,
        adds: results[2] as List<PendingAdd>,
        invites: results[3] as List<TeamInvite>,
        offices: results[4] as List<Office>,
      );
      loaded = true;
      loadError = null;
    } catch (e) {
      final message = ApiError.from(e).message;
      // A pull that fails while lists are showing keeps them and says so above them.
      if (!loaded || !refresh) {
        loadError = message;
      } else {
        actionError = message;
      }
    } finally {
      loading = false;
      _notify();
    }
  }

  void dismissError() {
    if (actionError == null) return;
    actionError = null;
    _notify();
  }

  // --- a row's own buttons (the error shows above the lists) ---------------------------------------------------

  /// Runs one write for a row: busy while it runs, the error above the lists if it was refused, every list read
  /// again after it worked. False when refused or when another row is busy.
  Future<bool> _row(String key, Future<void> Function() write) async {
    if (busy) return false;
    busyKey = key;
    actionError = null;
    _notify();
    try {
      await write();
    } catch (e) {
      actionError = ApiError.from(e).message;
      busyKey = null;
      _notify();
      return false;
    }
    busyKey = null;
    _notify();
    await load(refresh: true);
    return true;
  }

  Future<bool> decline(TeamRequest request) =>
      _row('decline:${request.userId}', () => repository.decline(request.userId));

  Future<bool> cancelAdd(PendingAdd add) => _row('cancel:${add.userId}', () => repository.cancelAdd(add.userId));

  Future<bool> revoke(TeamInvite invite) => _row('revoke:${invite.id}', () => repository.revokeInvite(invite.id));

  Future<bool> remove(TeamMember member) => _row('remove:${member.id}', () => repository.removeMember(member.id));

  // --- a sheet's send (the sentence goes back to the sheet, which keeps what was typed) --------------------------

  /// Runs one write for a sheet: null when it worked (every list is read again), else the API's sentence.
  Future<String?> _sheet(String key, Future<void> Function() write) async {
    if (busy) return 'Another change is still running.';
    busyKey = key;
    _notify();
    try {
      await write();
    } catch (e) {
      busyKey = null;
      _notify();
      return ApiError.from(e).message;
    }
    busyKey = null;
    _notify();
    await load(refresh: true);
    return null;
  }

  /// Approves a request with the role (and office) the admin named.
  Future<String?> approve(TeamRequest request, {required String role, String? branchId}) =>
      _sheet('approve:${request.userId}', () => repository.approve(request.userId, role: role, branchId: branchId));

  /// Changes a member's role and/or office; [patch] holds only what changed.
  Future<String?> update(TeamMember member, Map<String, Object?> patch) =>
      _sheet('edit:${member.id}', () => repository.updateMember(member.id, patch));

  /// Asks someone already on ICR; they join once they accept from My companies.
  Future<String?> addPerson(
    TeamPerson person, {
    required String role,
    String? branchId,
    List<String> learningRoles = const [],
  }) => _sheet(
    'add:${person.id}',
    () => repository.addMember(userId: person.id, role: role, branchId: branchId, learningRoles: learningRoles),
  );

  /// Sends an email invite.
  Future<String?> inviteByEmail({
    required String email,
    required String role,
    String? branchId,
    List<String> learningRoles = const [],
  }) => _sheet(
    'invite',
    () => repository.invite(email: email, role: role, branchId: branchId, learningRoles: learningRoles),
  );
}
