import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'assess_models.dart';
import 'assess_repository.dart';
import 'catalogue_controller.dart';

/// Everything a paper's card says: what the member holds, how they did, and what opening it takes.
class PaperEntry {
  const PaperEntry({
    required this.paper,
    required this.access,
    required this.progress,
    required this.certified,
    required this.redeemed,
    required this.busy,
    this.quote,
  });

  final AssessPaper paper;
  final PaperAccess access;
  final PaperProgress progress;
  final bool certified;

  /// The member opened it with ICR credits.
  final bool redeemed;

  /// A redemption is in flight.
  final bool busy;

  /// What opening it costs; only read for a paper that is closed to the member.
  final PaperQuote? quote;

  bool get isOpen => access == PaperAccess.open;

  /// Every attempt the paper allows is used.
  bool get attemptsUsedUp => paper.attemptLimit != null && progress.attempts >= paper.attemptLimit!;

  int? get attemptsLeft => paper.attemptLimit == null ? null : (paper.attemptLimit! - progress.attempts).clamp(0, 9999);

  /// A price is on offer: the paper has one and the member would pay it.
  bool get priced => quote != null && quote!.priced;

  /// ICR credits open it (and what they cost), when the API says so.
  int? get credits => quote?.credits;
}

/// One programme's levels or one subject's sets: the group read afresh, the member's unlocks (shared with the
/// landing, through [catalogue]), the quotes of the papers still closed to them, the bundle offer, and the two
/// things a member does here: spend ICR credits on a paper and open the whole course with a plan place.
class GroupController extends ChangeNotifier {
  GroupController({required this.repository, required this.catalogue, required PaperGroup seed}) : _group = seed {
    // What the member holds is the landing's: an unlock made anywhere redraws these cards.
    catalogue.addListener(_notify);
  }

  final AssessRepository repository;
  final CatalogueController catalogue;

  PaperGroup _group;
  final Map<String, PaperQuote> _quotes = {};
  BundleQuote? _bundle;
  AssessmentPricing _pricing = const AssessmentPricing();
  bool _loading = false;
  bool _started = false;
  bool _notFound = false;
  String? _error;
  final Set<String> _busy = {};
  bool _opening = false;
  bool _bundleBusy = false;
  bool _disposed = false;
  int _generation = 0;

  PaperGroup get group => _group;
  PaperKind get kind => _group.kind;
  bool get started => _started;
  bool get loading => _loading;
  bool get notFound => _notFound;
  String? get error => _error;
  bool get openingWithPlan => _opening;

  /// A bundle redemption is in flight.
  bool get redeemingBundle => _bundleBusy;

  /// The "all levels" / "all sets" offer, when the API has one on offer for this member (in money, credits or both).
  BundleQuote? get bundle => _bundle;
  AssessmentPricing get pricing => _pricing;
  MemberLearning get member => catalogue.member;

  /// Where the course or exam stands for this member; null when their unlocks are not known.
  PlaceState? get placeState => member.access?.stateOf(kind, _group.id);

  PaperEntry entry(AssessPaper paper) {
    final access = member.accessOf(paper);
    return PaperEntry(
      paper: paper,
      access: access,
      progress: member.progressOf(paper.id),
      certified: member.certified.contains(paper.id),
      redeemed: member.access?.redeemedWithCredits(paper) ?? false,
      busy: _busy.contains(paper.id),
      quote: access == PaperAccess.closed ? _quotes[paper.id] : null,
    );
  }

  /// The papers the member opened with ICR credits (the "You enrolled with ICR referral credits" notes).
  List<AssessPaper> get redeemedPapers => [
    for (final p in _group.papers)
      if (member.access?.redeemedWithCredits(p) ?? false) p,
  ];

  /// Some of its papers can be bought one at a time; all of them can.
  bool get anyPriced => _group.papers.any((p) => p.priced);
  bool get allPriced => _group.papers.isNotEmpty && _group.papers.every((p) => p.priced);

  /// A global discount is on and a level shows a price for it: the strip above the levels.
  bool get showDiscount =>
      kind == PaperKind.assessment && _pricing.discountPercent > 0 && _quotes.values.any((q) => q.priced);

  Future<void> start() async {
    _started = true;
    // A page opened from somewhere that never started its catalogue (a flash-card deck's "Open the course", a hub
    // card) has not read what the member holds: read it now, or every level would show open.
    await _load(notify: false, member: catalogue.member.access == null);
  }

  /// Pull to refresh: the group, what the member holds, the quotes.
  Future<void> refresh() => _load(notify: true, member: true);

  Future<void> _load({required bool notify, required bool member}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (notify) _notify();
    try {
      try {
        final fresh = await repository.group(kind, _group.key);
        if (generation != _generation) return;
        _group = fresh;
        _notFound = false;
        catalogue.update(fresh);
      } catch (e) {
        if (generation != _generation) return;
        final error = ApiError.from(e);
        if (error.statusCode == 404) {
          _notFound = true;
        } else {
          // The grid's copy is a moment old, not wrong: keep it on show and say the refresh failed.
          _error = error.message;
        }
      }
      if (member) await catalogue.refreshMember();
      if (generation != _generation) return;
      await _loadPrices(generation);
    } finally {
      if (generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  /// The quotes of the papers still closed to the member, the bundle offer and the global discount: each a
  /// read that may fail without taking the page with it.
  Future<void> _loadPrices(int generation) async {
    final closed = [
      for (final p in _group.papers)
        if (member.accessOf(p) == PaperAccess.closed) p,
    ];
    final quotes = await Future.wait([for (final p in closed) _quietQuote(p)]);
    // A bundle is offered on a programme's page and on a mock subject's page alike, to a member whose unlocks are known.
    final bundle = member.access != null ? await _quietBundle() : null;
    final pricing = kind == PaperKind.assessment ? await _quietPricing() : _pricing;
    if (generation != _generation) return;
    _quotes
      ..clear()
      ..addEntries([for (final q in quotes) ?q]);
    _bundle = bundle;
    _pricing = pricing;
  }

  Future<MapEntry<String, PaperQuote>?> _quietQuote(AssessPaper p) async {
    try {
      return MapEntry(p.id, await repository.quote(p));
    } catch (_) {
      return null;
    }
  }

  Future<BundleQuote?> _quietBundle() async {
    try {
      return await repository.bundleQuote(_group.key, kind: kind);
    } catch (_) {
      return null;
    }
  }

  Future<AssessmentPricing> _quietPricing() async {
    try {
      return await repository.pricing();
    } catch (_) {
      return _pricing;
    }
  }

  /// Spends ICR credits to open [paper] for good. Null on success, else the API's sentence (nothing is
  /// changed: the card stays locked and the credits stay).
  Future<String?> redeem(AssessPaper paper) async {
    if (_busy.contains(paper.id)) return null;
    _busy.add(paper.id);
    _notify();
    try {
      final result = await repository.redeem(paper);
      catalogue.unlockLocally(paper.id, credits: result.credits, withCredits: true);
      _quotes.remove(paper.id);
      await catalogue.refreshMember();
      _bundle = await _quietBundle();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _busy.remove(paper.id);
      _notify();
    }
  }

  /// Redeems the whole bundle in ICR credits: every closed level or set opens at once, for what the API's quote
  /// says. The cards flip to open, the balance drops and the flash-card decks that follow these courses open with
  /// them. Returns what it did, or the API's own sentence when it refused (nothing is changed then: not enough
  /// credits, a level opened meanwhile).
  Future<BundleRedeemOutcome> redeemBundle() async {
    if (_bundleBusy) return const BundleRedeemOutcome();
    _bundleBusy = true;
    _notify();
    try {
      final result = await repository.redeemBundle(kind, _group.key);
      catalogue.unlockBundleLocally(
        result.paperIds,
        credits: result.credits,
        courseIds: result.unlockedCourseIds.isNotEmpty
            ? result.unlockedCourseIds
            : [if (kind == PaperKind.assessment) _group.id],
      );
      for (final id in result.paperIds) {
        _quotes.remove(id);
      }
      await catalogue.refreshMember();
      _bundle = await _quietBundle();
      return BundleRedeemOutcome(opened: result.paperIds.length, spent: result.spent);
    } catch (e) {
      // A refusal may mean what is left changed meanwhile: the offer is quoted again.
      final message = ApiError.from(e).message;
      _bundle = await _quietBundle();
      return BundleRedeemOutcome(error: message);
    } finally {
      _bundleBusy = false;
      _notify();
    }
  }

  /// Opens the whole course or mock exam with one of the plan's places. Null on success, else the API's sentence.
  Future<String?> openWithPlan() async {
    if (_opening) return null;
    _opening = true;
    _notify();
    try {
      await repository.openWithPlan(kind, _group.id);
      catalogue.openPlaceLocally(kind, _group.id);
      await catalogue.refreshMember();
      _quotes.clear();
      _bundle = await _quietBundle();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _opening = false;
      _notify();
    }
  }

  /// A sitting ended (or the exam was left): its attempts and best score are read again.
  Future<void> afterSitting() async {
    await catalogue.refreshMember();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    catalogue.removeListener(_notify);
    super.dispose();
  }
}

/// What redeeming a bundle did: how many levels or sets opened and what it cost, or the API's refusal.
class BundleRedeemOutcome {
  const BundleRedeemOutcome({this.opened = 0, this.spent = 0, this.error});

  final int opened;
  final int spent;
  final String? error;

  bool get ok => error == null && opened > 0;
}
