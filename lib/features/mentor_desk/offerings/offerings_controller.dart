import 'package:flutter/foundation.dart';

import '../../../core/api/api_error.dart';
import '../../mentorship_my/loader.dart';
import 'offerings_models.dart';
import 'offerings_repository.dart';

/// What the Offerings panel holds: the seller gates and services, the plans and
/// programmes, the group sessions the mentor hosts. Each is its own read, so one
/// failing leaves the others on screen. An action answers the API's refusal as a
/// sentence, or null when it went through, reloads what it changed and tells
/// the desk ([onChanged]) so its overview can read again.
class OfferingsController extends ChangeNotifier {
  OfferingsController(this.repository, {this.onChanged}) {
    storefront = Loader(repository.storefront, _notify);
    plans = Loader(repository.plans, _notify);
    sessions = Loader(repository.sessions, _notify);
  }

  final OfferingsRepository repository;
  final VoidCallback? onChanged;

  late final Loader<Storefront> storefront;
  late final Loader<List<OfferedPlan>> plans;
  late final Loader<List<HostedSession>> sessions;

  bool _disposed = false;
  bool _started = false;

  bool get started => _started;

  Future<void> start() {
    if (_started) return Future.value();
    _started = true;
    return refresh();
  }

  Future<void> refresh() => Future.wait([storefront.load(), plans.load(), sessions.load()]);

  // --- derived -----------------------------------------------------------------------

  StorefrontGates? get gates => storefront.data?.gates;
  List<OfferedService> get services => storefront.data?.services ?? const [];

  /// 1:1 sessions, nearest to the top as the API orders them.
  List<OfferedService> get singles => [
    for (final s in services)
      if (s.kind == ServiceKind.oneOnOne) s,
  ];
  List<OfferedService> get resources => [
    for (final s in services)
      if (s.kind == ServiceKind.resource) s,
  ];

  /// Older seat listings (a seat now sells from the session itself): kept editable, never created.
  List<OfferedService> get legacySeats => [
    for (final s in services)
      if (s.kind == ServiceKind.groupSeat) s,
  ];
  List<OfferedService> get retired => [
    for (final s in services)
      if (s.kind.retired) s,
  ];
  List<OfferedPlan> get programmes => [
    for (final p in plans.data ?? const <OfferedPlan>[])
      if (p.programme) p,
  ];
  List<OfferedPlan> get ongoing => [
    for (final p in plans.data ?? const <OfferedPlan>[])
      if (!p.programme) p,
  ];

  /// Listings as the API counts them against the cap: every service that is not deleted, drafts included.
  int get listingsUsed => services.length;

  // --- actions -------------------------------------------------------------------------

  Future<String?> acceptTerms() => _act(() async {
    final version = gates?.termsCurrentVersion;
    if (version == null) throw ApiError('Reload and read the seller terms again.');
    storefront.data = await repository.acceptTerms(version);
    storefront.error = null;
    storefront.loaded = true;
  });

  /// Creates a service ([id] null) or saves it (the whole shape, as the API takes it).
  Future<String?> saveService(Map<String, Object?> body, {String? id}) => _act(() async {
    if (id == null) {
      await repository.createService(body);
    } else {
      await repository.updateService(id, body);
    }
    await storefront.load();
  });

  /// Pauses or resumes a service: the API takes the whole shape, so this row goes back with only `active` changed.
  Future<String?> setServiceActive(OfferedService s, bool active) => _act(() async {
    await repository.updateService(s.id, s.body(active: active));
    await storefront.load();
  });

  Future<String?> deleteService(OfferedService s) => _act(() async {
    await repository.deleteService(s.id);
    await storefront.load();
  });

  Future<String?> savePlan(Map<String, Object?> body, {String? id}) => _act(() async {
    if (id == null) {
      await repository.createPlan(body);
    } else {
      await repository.updatePlan(id, body);
    }
    await plans.load();
  });

  /// Pauses or resumes a plan or programme: a partial patch of `active` alone.
  Future<String?> setPlanActive(OfferedPlan p, bool active) => _act(() async {
    await repository.updatePlan(p.id, {'active': active});
    await plans.load();
  });

  Future<String?> deletePlan(OfferedPlan p) => _act(() async {
    await repository.deletePlan(p.id);
    await plans.load();
  });

  Future<String?> saveSession(Map<String, Object?> body, {String? id}) => _act(() async {
    if (id == null) {
      await repository.createSession(body);
    } else {
      await repository.updateSession(id, body);
    }
    await sessions.load();
  });

  Future<String?> publishSession(HostedSession s) => _act(() async {
    await repository.publishSession(s.id);
    await sessions.load();
  });

  Future<String?> cancelSession(HostedSession s, String reason) => _act(() async {
    await repository.cancelSession(s.id, reason);
    await sessions.load();
  });

  Future<String?> completeSession(HostedSession s, List<String> attendedIds, {int? durationMin, String? note}) =>
      _act(() async {
        await repository.completeSession(s.id, attendedIds, durationMin: durationMin, note: note);
        await sessions.load();
      });

  /// One session with its roster. Throws the API's refusal as an [ApiError].
  Future<HostedSession> detail(HostedSession s) => repository.session(s.id);

  Future<StoredUpload> upload(PickedUpload file, {required String purpose}) =>
      repository.upload(file, purpose: purpose);

  Future<String?> _act(Future<void> Function() action) async {
    try {
      await action();
      onChanged?.call();
      _notify();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
