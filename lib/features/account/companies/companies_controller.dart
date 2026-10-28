import 'package:flutter/foundation.dart';

import '../../../core/api/api_error.dart';
import '../account_models.dart';
import '../account_repository.dart';

/// Takes the fresh token pair a switch, a leave or a create hands back
/// (`AuthController.adoptSession`). The role rides in the token, so every call
/// after it must use the new pair.
typedef SessionAdopter = Future<void> Function(SessionTokens tokens);

/// "My companies": the list the person reads, and the four things they do to
/// it (act for another company or for themselves, leave one, take back a
/// request, ask to join one). The website's `/account/companies`.
///
/// A switch, a leave and a create each return a fresh session, because the
/// role rides in the access token. The controller adopts it, tells the app
/// through [onSessionChanged] to drop whatever it cached for the previous
/// company (the website resets every query for the same reason), and reads the
/// list again.
class CompaniesController extends ChangeNotifier {
  CompaniesController({required this.repository, required this.adopt, this.onSessionChanged});

  final AccountRepository repository;
  final SessionAdopter adopt;

  /// The company being acted for changed: reset cached answers.
  final VoidCallback? onSessionChanged;

  /// Stands for the personal account in [switching] (a company id never looks like this).
  static const personal = '@personal';

  MyCompanies? data;

  /// The first read, or a Retry, is in flight and there is nothing to show yet.
  bool loading = true;

  /// Why the list could not be read (shown with Retry when there is no list).
  String? loadError;

  /// What the last action was refused with, shown above the list.
  String? actionError;

  /// The company being switched to ([personal] for the personal account).
  String? switching;

  /// The company being left.
  String? leaving;

  /// The request being withdrawn.
  String? withdrawing;

  bool _disposed = false;

  bool get busy => switching != null || leaving != null || withdrawing != null;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // --- reading -----------------------------------------------------------------------------------------------

  /// Reads the list. [refresh] keeps what is on screen while it loads (pull to
  /// refresh); otherwise the screen shows its loading state.
  Future<void> load({bool refresh = false}) async {
    if (!refresh) {
      loading = true;
      loadError = null;
      _notify();
    }
    try {
      data = await repository.myCompanies();
      loadError = null;
    } catch (e) {
      final message = ApiError.from(e).message;
      // A pull that fails while a list is showing keeps the list and says so above it.
      if (data == null || !refresh) {
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

  // --- acting ------------------------------------------------------------------------------------------------

  /// Acts for [companyId], or for the person themselves (null). False when it
  /// was refused or another action is running; the sentence is in [actionError].
  Future<bool> switchTo(String? companyId) async {
    if (busy) return false;
    return _session(
      start: () => switching = companyId ?? personal,
      end: () => switching = null,
      call: () => repository.switchCompany(companyId),
    );
  }

  /// Leaves [company]. Null when it worked, else the API's sentence (the
  /// dialog keeps it beside the button that caused it).
  Future<String?> leave(MyCompany company) async {
    if (busy) return 'Another action is still running.';
    String? failure;
    await _session(
      start: () => leaving = company.companyId,
      end: () => leaving = null,
      call: () => repository.leaveCompany(company.companyId),
      onFailure: (message) => failure = message,
      removed: company.companyId,
      quiet: true,
    );
    return failure;
  }

  /// Takes back a request no admin has decided yet.
  Future<bool> withdraw(String companyId) async {
    if (busy) return false;
    withdrawing = companyId;
    actionError = null;
    _notify();
    try {
      data = await repository.withdrawRequest(companyId);
      return true;
    } catch (e) {
      actionError = ApiError.from(e).message;
      return false;
    } finally {
      withdrawing = null;
      _notify();
    }
  }

  /// Asks the company's admins to add the person. Null when sent, else the API's sentence.
  Future<String?> requestToJoin(String companyId, String? note) async {
    try {
      await repository.requestToJoin(companyId, note: note);
    } catch (e) {
      return ApiError.from(e).message;
    }
    await load(refresh: true);
    return null;
  }

  /// A switch, a leave or a create: call the API, take the session it returns,
  /// tell the app, and make the list say what is now true.
  Future<bool> _session({
    required VoidCallback start,
    required VoidCallback end,
    required Future<SessionTokens> Function() call,
    void Function(String message)? onFailure,
    String? removed,
    bool quiet = false,
  }) async {
    start();
    actionError = null;
    _notify();
    try {
      final tokens = await call();
      await adopt(tokens);
      onSessionChanged?.call();
      // Until the list is read again, show what the new session says.
      final data = this.data;
      if (data != null) {
        final kept = removed == null
            ? data
            : data.copyWith(companies: [
                for (final c in data.companies)
                  if (c.companyId != removed) c,
              ]);
        this.data = tokens.user == null ? kept : _withActive(kept, tokens.user!['companyId'] as String?);
      }
      end();
      _notify();
      await load(refresh: true);
      return true;
    } catch (e) {
      final message = ApiError.from(e).message;
      onFailure?.call(message);
      if (!quiet) actionError = message;
      return false;
    } finally {
      end();
      _notify();
    }
  }

  /// [data] with exactly [activeId] marked as the company being acted for.
  static MyCompanies _withActive(MyCompanies data, String? activeId) => MyCompanies(
    personalRole: data.personalRole,
    canJoinCompanies: data.canJoinCompanies,
    requests: data.requests,
    companies: [
      for (final c in data.companies)
        MyCompany(
          companyId: c.companyId,
          name: c.name,
          role: c.role,
          logoUrl: c.logoUrl,
          branchName: c.branchName,
          active: c.companyId == activeId,
          hasSupplierListing: c.hasSupplierListing,
          city: c.city,
          state: c.state,
          industry: c.industry,
          verified: c.verified,
          joinedAt: c.joinedAt,
          memberCount: c.memberCount,
          soleAdmin: c.soleAdmin,
          pendingJoinRequests: c.pendingJoinRequests,
        ),
    ],
  );
}
