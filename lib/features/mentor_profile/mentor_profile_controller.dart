import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'mentor_profile_models.dart';
import 'mentor_profile_navigation.dart';
import 'mentor_profile_repository.dart';

/// The tabs under the hero.
enum ProfileTab { overview, offerings, recommendations }

/// One mentor's page: the profile, what they sell, their reviews, which tab
/// and filter is open, and the member's actions on them (applied at once,
/// rolled back if the API refuses).
class MentorProfileController extends ChangeNotifier {
  MentorProfileController({
    required this.repository,
    required this.mentorId,
    this.navigation = const MentorProfileNavigation(),
  });

  final MentorProfileRepository repository;
  final String mentorId;

  /// Where the page's buttons lead in the rest of the app (the app's own screens unless replaced).
  final MentorProfileNavigation navigation;

  MentorProfile? _profile;
  List<MentorOffering> _offerings = const [];
  List<MentorReview> _reviews = const [];
  bool _loading = false;
  bool _started = false;
  String? _error;
  int _unread = 0;
  ProfileTab _tab = ProfileTab.overview;
  OfferingFilter _filter = OfferingFilter.all;
  bool _bioExpanded = false;
  bool _busy = false;

  MentorProfile? get profile => _profile;
  List<MentorOffering> get offerings => _offerings;
  List<MentorReview> get reviews => _reviews;
  bool get loading => _loading;
  bool get started => _started;
  String? get error => _error;
  int get unread => _unread;
  ProfileTab get tab => _tab;
  OfferingFilter get filter => _filter;
  bool get bioExpanded => _bioExpanded;

  /// An action is in flight; the buttons wait for it.
  bool get busy => _busy;

  /// The dark card: the mentor's ongoing plan (the cheapest per month).
  MentorOffering? get featuredPlan {
    final plans = _offerings.where((o) => o.kind == OfferingKind.plan).toList()
      ..sort((a, b) => (a.perMonthPaisa ?? a.pricePaisa).compareTo(b.perMonthPaisa ?? b.pricePaisa));
    return plans.firstOrNull;
  }

  /// The Offerings tab's rows: everything but the featured plan, narrowed by
  /// the filter. A programme listed in several terms is one row (its shortest
  /// term, where the family first appears); the sheet offers the others.
  List<MentorOffering> get rows {
    final seen = <String>{};
    final out = <MentorOffering>[];
    for (final o in _offerings) {
      if (o.id == featuredPlan?.id) continue;
      var row = o;
      final family = o.familyKey;
      if (family != null) {
        if (!seen.add(family)) continue;
        row = variantsOf(o).first;
      }
      if (_filter.admits(row)) out.add(row);
    }
    return out;
  }

  /// The terms one programme is listed in, shortest first; just [o] when it
  /// has no siblings.
  List<MentorOffering> variantsOf(MentorOffering o) {
    final family = o.familyKey;
    if (family == null) return [o];
    return _offerings.where((x) => x.familyKey == family).toList()
      ..sort((a, b) => (a.termMonths ?? 0).compareTo(b.termMonths ?? 0));
  }

  /// Every filter chip; one with nothing behind it says so under the list.
  List<OfferingFilter> get filters => OfferingFilter.values;

  /// The free 1:1 session the hero's "Book Trial (₹0)" opens, when the mentor
  /// sells one; otherwise the hero asks for free mentoring.
  MentorOffering? get trialOffering => _offerings.where((o) => o.kind == OfferingKind.oneOnOne && o.free).firstOrNull;

  Future<void> load() async {
    _started = true;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final profile = await repository.profile(mentorId);
      _profile = profile;
      _loading = false;
      notifyListeners();
      final results = await Future.wait([
        repository.offerings(profile),
        repository.reviews(profile),
        repository.unreadNotifications().catchError((_) => 0),
      ]);
      _offerings = results[0] as List<MentorOffering>;
      _reviews = results[1] as List<MentorReview>;
      _unread = results[2] as int;
    } catch (e) {
      _error = ApiError.from(e).message;
      _loading = false;
    }
    notifyListeners();
  }

  void selectTab(ProfileTab tab) {
    if (_tab == tab) return;
    _tab = tab;
    notifyListeners();
  }

  void selectFilter(OfferingFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    notifyListeners();
  }

  void expandBio() {
    _bioExpanded = true;
    notifyListeners();
  }

  Future<bool> needsPhone() async {
    try {
      return !await repository.hasPhone();
    } catch (_) {
      return false;
    }
  }

  /// The free mentoring request; a sentence when the API refuses.
  Future<String?> requestMentoring({required String message, String? phone}) async {
    final profile = _profile;
    if (profile == null) return 'The profile has not loaded yet.';
    final before = profile.viewer;
    _profile = profile.copyWith(
      viewer: (before ?? const MentorViewer()).copyWith(
        canRequest: false,
        blocker: AskBlocker.requestPending,
        blockedReason: 'Your request is with this mentor, awaiting a reply.',
        pendingRequestId: 'pending',
      ),
    );
    _busy = true;
    notifyListeners();
    try {
      await repository.requestMentoring(profile, message: message, phone: phone);
      return null;
    } catch (e) {
      _profile = profile.copyWith(viewer: before);
      return ApiError.from(e).message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// The conversation id of a live pairing's thread; null when there is none.
  Future<String?> openConversation() async {
    final profile = _profile;
    if (profile == null) return null;
    return repository.openConversation(profile);
  }

  /// Asks for a 1:1 session; the row then says the request is in play.
  Future<String?> requestSession(
    MentorOffering offering, {
    required String topic,
    required String mode,
    String? preferredTimes,
    String? phone,
  }) async {
    _replace(offering.copyWith(myOpenRequestId: 'pending'));
    _busy = true;
    notifyListeners();
    try {
      final id = await repository.requestSession(
        offering,
        topic: topic,
        mode: mode,
        preferredTimes: preferredTimes,
        phone: phone,
      );
      _replace(offering.copyWith(myOpenRequestId: id ?? 'pending'));
      return null;
    } catch (e) {
      _replace(offering.copyWith(clearRequest: true));
      return ApiError.from(e).message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Buys or asks for an offering; the outcome says what to do next.
  Future<CheckoutOutcome> buy(MentorOffering offering, {String? phone}) async {
    final profile = _profile;
    if (profile == null) {
      return const CheckoutOutcome(CheckoutState.refused, message: 'The profile has not loaded yet.');
    }
    _busy = true;
    notifyListeners();
    try {
      final outcome = await repository.buy(profile, offering, phone: phone);
      if (outcome.state == CheckoutState.requested) {
        _replace(offering.copyWith(myOpenRequestId: 'pending'));
      }
      return outcome;
    } catch (e) {
      return CheckoutOutcome(CheckoutState.refused, message: ApiError.from(e).message);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _replace(MentorOffering offering) {
    _offerings = [for (final o in _offerings) o.id == offering.id ? offering : o];
    notifyListeners();
  }
}
