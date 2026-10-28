import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'rfq_models.dart';
import 'rfq_repository.dart';

/// How the owner orders the bids.
enum BidSort {
  price('Lowest price'),
  rating('Highest rating'),
  lead('Fastest lead time');

  const BidSort(this.label);
  final String label;
}

/// The owner's page of one requirement: where it stands, the bids or the
/// pre-qualification responses, the suppliers invited and the threads with
/// them, and every decision the owner takes. Reversible moves (shortlist,
/// decline, qualify, publish, close, cancel, the stage) show at once and go
/// back if the API refuses; an award, which cannot be undone, waits for it.
class RfqDetailController extends ChangeNotifier {
  RfqDetailController({required this.repository, required this.rfqId});

  final RfqRepository repository;
  final String rfqId;

  Requirement? _rfq;
  List<Bid> _bids = const [];
  List<PreQualResponse> _responses = const [];
  List<SupplierInvite> _invites = const [];
  List<SupplierThread> _threads = const [];
  bool _loading = false;
  String? _error;

  /// The page loaded but the bids were refused: someone else's requirement.
  String? _notOwner;
  BidSort _sort = BidSort.price;
  int _unread = 0;
  bool _started = false;
  final Set<String> _busy = {};
  bool _acting = false;
  int _generation = 0;

  Requirement? get rfq => _rfq;
  List<Bid> get bids => _bids;
  List<PreQualResponse> get responses => _responses;
  List<SupplierInvite> get invites => _invites;
  List<SupplierThread> get threads => _threads;
  bool get loading => _loading;
  String? get error => _error;
  String? get notOwner => _notOwner;
  BidSort get sort => _sort;
  int get unread => _unread;
  bool get started => _started;

  /// A lifecycle move (publish, close, cancel, delete, the stage) is under way.
  bool get acting => _acting;
  bool isBusy(String id) => _busy.contains(id);

  /// Quotes are being taken or weighed: the staged RFQ's bids are shown.
  bool get quotesOpen => _rfq?.stage == RfqStage.quotation || _rfq?.stage == RfqStage.evaluation;

  /// A bid may be awarded: the requirement is live, or an enquiry closed on its date.
  bool get canAward => (_rfq?.live ?? false) || (_rfq?.expiredEnquiry ?? false);

  /// The bids in the owner's order: awarded, shortlisted, new, declined; then by the sort.
  List<Bid> get sortedBids {
    int rank(BidStatus s) => switch (s) {
      BidStatus.awarded => 0,
      BidStatus.shortlisted => 1,
      BidStatus.pending => 2,
      BidStatus.rejected => 3,
    };
    int metric(Bid a, Bid b) => switch (_sort) {
      BidSort.price => (a.amount ?? double.infinity).compareTo(b.amount ?? double.infinity),
      BidSort.rating => b.supplier.rating.compareTo(a.supplier.rating),
      BidSort.lead => (a.leadTimeDays ?? 1 << 30).compareTo(b.leadTimeDays ?? 1 << 30),
    };
    return [..._bids]..sort((a, b) {
      final r = rank(a.status).compareTo(rank(b.status));
      return r != 0 ? r : metric(a, b);
    });
  }

  /// The lowest price among the live bids, when there is more than one to compare.
  double? get bestPrice {
    final priced = [
      for (final b in _bids)
        if (b.status != BidStatus.rejected && b.amount != null) b.amount!,
    ];
    return priced.length > 1 ? priced.reduce((a, b) => a < b ? a : b) : null;
  }

  Future<void> start() async {
    _started = true;
    await Future.wait([_load(notify: false), _loadUnread()]);
    try {
      await repository.markSeen(AlertSide.owner, rfqId);
    } catch (_) {
      // Read-sync is a courtesy.
    }
  }

  Future<void> refresh() => _load(notify: true);

  /// Why the responses are not shown. A member of the requirement's own company, in a role that does not run
  /// requirements (an office admin, a recruiter, a hiring manager), is told it is their company's and what their
  /// role may do; anyone else is told it belongs to another company or person.
  Future<String> _notOwnerWords(Requirement rfq) async {
    const other = 'This requirement belongs to another company or person, so its responses are not yours to see.';
    try {
      final me = await repository.me();
      if (me.roleCannotPost && rfq.companyId != null && rfq.companyId == me.companyId) {
        final at = (me.companyName ?? '').trim().isEmpty ? 'your company' : me.companyName!;
        return "This is a requirement of $at. Its replies and invitations are for the company's admins and buyers; "
            'as ${me.roleWords} you can read the brief only.';
      }
    } catch (_) {
      // The general sentence stands.
    }
    return other;
  }

  Future<void> _load({required bool notify}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (notify) notifyListeners();
    try {
      final rfq = await repository.requirement(rfqId);
      if (generation != _generation) return;
      _rfq = rfq;
      _notOwner = null;
      try {
        await _loadResponses(rfq);
      } on Object catch (e) {
        final error = ApiError.from(e);
        if (error.statusCode == 403) {
          _notOwner = await _notOwnerWords(rfq);
        } else {
          rethrow;
        }
      }
    } catch (e) {
      if (generation != _generation) return;
      _error = ApiError.from(e).message;
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadResponses(Requirement rfq) async {
    final staged = rfq.staged;
    final wantBids =
        !staged ||
        rfq.stage == RfqStage.quotation ||
        rfq.stage == RfqStage.evaluation ||
        rfq.stage == RfqStage.completed;
    final results = await Future.wait<Object?>([
      wantBids ? repository.bids(rfqId) : Future.value(const <Bid>[]),
      staged ? repository.responses(rfqId) : Future.value(const <PreQualResponse>[]),
      staged ? Future.value(const <SupplierInvite>[]) : repository.invites(rfqId),
      repository.threads(rfqId).catchError((Object _) => const <SupplierThread>[]),
    ]);
    _bids = results[0] as List<Bid>;
    _responses = results[1] as List<PreQualResponse>;
    _invites = results[2] as List<SupplierInvite>;
    _threads = results[3] as List<SupplierThread>;
  }

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      notifyListeners();
    } catch (_) {}
  }

  void setSort(BidSort sort) {
    if (sort == _sort) return;
    _sort = sort;
    notifyListeners();
  }

  // ---- The requirement itself ----------------------------------------------------

  /// Publish, close or cancel: shown at once, put back if refused.
  Future<String?> act(RfqAction action) async {
    final before = _rfq;
    if (before == null || _acting) return null;
    final to = switch (action) {
      RfqAction.publish => RfqStatus.published,
      RfqAction.close => RfqStatus.closed,
      RfqAction.cancel => RfqStatus.cancelled,
    };
    _acting = true;
    _rfq = before.copyWith(
      status: to,
      stage: action == RfqAction.publish && before.kind == RfqKind.rfq && before.stage == null
          ? RfqStage.prequalification
          : null,
    );
    notifyListeners();
    try {
      await repository.act(rfqId, action);
      _acting = false;
      await _quietReload();
      return null;
    } catch (e) {
      _acting = false;
      _rfq = before;
      notifyListeners();
      return ApiError.from(e).message;
    }
  }

  /// Deletes the draft; the caller leaves the page when this answers null.
  Future<String?> deleteDraft() async {
    if (_rfq?.status != RfqStatus.draft || _acting) return null;
    _acting = true;
    notifyListeners();
    try {
      await repository.deleteDraft(rfqId);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _acting = false;
      notifyListeners();
    }
  }

  /// Moves a staged RFQ to its next stage.
  Future<String?> advanceStage() async {
    final before = _rfq;
    final next = before?.stage?.next;
    if (before == null || next == null || _acting) return null;
    _acting = true;
    _rfq = before.copyWith(stage: next);
    notifyListeners();
    try {
      await repository.setStage(rfqId, next);
      _acting = false;
      await _quietReload();
      return null;
    } catch (e) {
      _acting = false;
      _rfq = before;
      notifyListeners();
      return ApiError.from(e).message;
    }
  }

  // ---- Bids ------------------------------------------------------------------------

  /// Shortlist, decline or put back to new.
  Future<String?> triage(Bid bid, BidStatus status) async {
    if (_busy.contains(bid.id)) return null;
    _busy.add(bid.id);
    _swapBid(bid.id, (b) => b.withStatus(status));
    try {
      await repository.triageBid(rfqId, bid.id, status);
      return null;
    } catch (e) {
      _swapBid(bid.id, (_) => bid);
      return ApiError.from(e).message;
    } finally {
      _busy.remove(bid.id);
      notifyListeners();
    }
  }

  /// Awards an RFQ's bid (raising a purchase order) or selects an enquiry's
  /// reply. Not optimistic: it cannot be undone. Returns the sentence to show.
  Future<({bool ok, String message})> award(Bid bid) async {
    final rfq = _rfq;
    if (rfq == null || _busy.contains(bid.id)) return (ok: false, message: '');
    _busy.add(bid.id);
    notifyListeners();
    try {
      final po = await repository.award(rfqId, bid.id);
      _bids = [
        for (final b in _bids)
          b.id == bid.id
              ? b.withStatus(BidStatus.awarded)
              : (b.status == BidStatus.rejected ? b : b.withStatus(BidStatus.rejected)),
      ];
      _rfq = rfq.copyWith(status: RfqStatus.awarded, stage: rfq.stage == null ? null : RfqStage.completed);
      final message = rfq.isEnquiry
          ? '${bid.supplier.name} selected. The other suppliers have been told.'
          : 'Awarded to ${bid.supplier.name}${po == null ? '' : ' — purchase order $po'}.';
      return (ok: true, message: message);
    } catch (e) {
      return (ok: false, message: ApiError.from(e).message);
    } finally {
      _busy.remove(bid.id);
      notifyListeners();
    }
  }

  // ---- Pre-qualification -------------------------------------------------------------

  Future<String?> screen(PreQualResponse response, PreQualStatus status) async {
    final id = response.supplier.vendorId;
    if (_busy.contains(id)) return null;
    _busy.add(id);
    _swapResponse(id, (r) => r.copyWith(status: status));
    try {
      await repository.screen(rfqId, id, status);
      return null;
    } catch (e) {
      _swapResponse(id, (_) => response);
      return ApiError.from(e).message;
    } finally {
      _busy.remove(id);
      notifyListeners();
    }
  }

  Future<String?> shortlist(PreQualResponse response) async {
    final id = response.supplier.vendorId;
    if (_busy.contains(id)) return null;
    _busy.add(id);
    _swapResponse(id, (r) => r.copyWith(shortlisted: true));
    try {
      await repository.shortlist(rfqId, [id]);
      return null;
    } catch (e) {
      _swapResponse(id, (_) => response);
      return ApiError.from(e).message;
    } finally {
      _busy.remove(id);
      notifyListeners();
    }
  }

  // ---- Suppliers ----------------------------------------------------------------------

  Future<List<SupplierHit>> suggested() => repository.suggested(rfqId);

  Future<List<SupplierHit>> findSuppliers(String query) => repository.findSuppliers(query);

  /// Invites the chosen suppliers; the list is what the API answers.
  Future<String?> invite(List<String> vendorIds) async {
    if (vendorIds.isEmpty) return 'Choose at least one supplier';
    try {
      _invites = await repository.invite(rfqId, vendorIds);
      notifyListeners();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  /// The thread with a supplier: the bid's own when it has one, else opened.
  Future<({String? id, String? error})> conversationWith({String? conversationId, String? supplierCompanyId}) async {
    if (conversationId != null) return (id: conversationId, error: null);
    if (supplierCompanyId == null) return (id: null, error: 'This supplier has no company to message.');
    try {
      return (id: await repository.openConversation(rfqId, supplierCompanyId: supplierCompanyId), error: null);
    } catch (e) {
      return (id: null, error: ApiError.from(e).message);
    }
  }

  // ---- Helpers --------------------------------------------------------------------------

  Future<void> _quietReload() async {
    try {
      final rfq = await repository.requirement(rfqId);
      _rfq = rfq;
      await _loadResponses(rfq);
    } catch (_) {
      // What is on screen stays; pull to refresh reads it again.
    }
    notifyListeners();
  }

  void _swapBid(String id, Bid Function(Bid) change) {
    _bids = [for (final b in _bids) b.id == id ? change(b) : b];
    notifyListeners();
  }

  void _swapResponse(String vendorId, PreQualResponse Function(PreQualResponse) change) {
    _responses = [for (final r in _responses) r.supplier.vendorId == vendorId ? change(r) : r];
    notifyListeners();
  }
}
