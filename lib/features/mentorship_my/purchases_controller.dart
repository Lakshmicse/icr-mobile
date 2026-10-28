import 'dart:typed_data';

import '../../core/api/api_error.dart';
import 'loader.dart';
import 'mentoring_models.dart';
import 'mentoring_repository.dart';

/// What the member bought or asked for: 1:1 sessions and their requests,
/// products, programme and plan terms, group seats and programme places.
/// It shares the page's change callback, so the page repaints as one.
///
/// An action answers the API's refusal as a sentence, or null when it went
/// through, and reloads what it changed. A payment returns what became of it
/// (done here, or continued on the website) and throws the API's refusal as an
/// [ApiError], which the sheet that asked shows in place.
class PurchasesBook {
  PurchasesBook(this.repository, void Function() changed) {
    purchases = Loader(repository.purchases, changed);
    terms = Loader(repository.planTerms, changed);
    seats = Loader(repository.groupSeats, changed);
    enrolments = Loader(repository.myProgrammes, changed);
    discounts = Loader(repository.memberDiscounts, changed);
  }

  final MentoringRepository repository;

  late final Loader<List<ServicePurchase>> purchases;
  late final Loader<List<PlanTerm>> terms;
  late final Loader<List<GroupSession>> seats;
  late final Loader<List<ProgrammeEnrolment>> enrolments;
  late final Loader<MemberDiscounts> discounts;

  Future<void> ensure() => Future.wait([purchases.ensure(), terms.ensure(), seats.ensure(), enrolments.ensure()]);

  Future<void> reload() => Future.wait([purchases.load(), terms.load(), seats.load(), enrolments.load()]);

  bool get loaded => purchases.loaded && terms.loaded;
  bool get loading => (purchases.loading && !purchases.loaded) || (terms.loading && !terms.loaded);
  String? get error => !purchases.loaded && !terms.loaded ? (purchases.error ?? terms.error) : null;

  /// What a price will be after the member's plan: read fresh each time a quote is about to be shown, because a
  /// credit may have been spent since the page loaded. A failure leaves the list price, never an invented one.
  Future<MemberDiscounts?> quoteInputs() async {
    await discounts.load();
    return discounts.data;
  }

  Future<String?> _act(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  // --- 1:1 sessions and products ----------------------------------------------

  Future<String?> withdrawRequest(ServicePurchase p) => _act(() async {
    await repository.withdrawPurchaseRequest(p.id);
    await purchases.load();
  });

  /// Takes the time the mentor set: it is booked on both calendars. A credit that covers the whole price may be
  /// spent here; otherwise the session is paid for after.
  Future<String?> acceptTime(ServicePurchase p, {bool useCredit = false}) => _act(() async {
    await repository.acceptTime(p.id, useCredit: useCredit);
    await purchases.load();
  });

  /// Sends the time back, saying when would suit.
  Future<String?> declineTime(ServicePurchase p, String note) => _act(() async {
    await repository.declineTime(p.id, note);
    await purchases.load();
  });

  Future<String?> cancel(ServicePurchase p, String reason) => _act(() async {
    await repository.cancelBooking(p.id, reason);
    await purchases.load();
  });

  /// Asks to move a booked call; the other person answers.
  Future<String?> proposeMove(ServicePurchase p, DateTime at, String note) => _act(() async {
    await repository.proposeReschedule(p.id, at, note: note);
    await purchases.load();
  });

  Future<String?> answerMove(ServicePurchase p, {required bool accept, String? reason}) => _act(() async {
    await repository.answerReschedule(p.id, accept: accept, reason: reason);
    await purchases.load();
  });

  Future<String?> review(ServicePurchase p, {required int rating, String? comment, bool anonymous = false}) =>
      _act(() async {
        await repository.reviewPurchase(p.id, rating: rating, comment: comment, anonymous: anonymous);
        await purchases.load();
      });

  Future<String?> reportIssue(ServicePurchase p, String note) => _act(() async {
    await repository.reportPurchaseIssue(p.id, note);
    await purchases.load();
  });

  Future<String?> withdrawIssue(ServicePurchase p) => _act(() async {
    await repository.withdrawPurchaseIssue(p.id);
    await purchases.load();
  });

  /// Pays for an accepted session as [quote] says. Throws the API's refusal as an [ApiError].
  Future<PaymentOutcome> payPurchase(ServicePurchase p, PriceQuote quote) async {
    final outcome = await repository.pay(p, quote: quote);
    if (outcome.completed) await purchases.load();
    return outcome;
  }

  /// A purchased file's bytes (private upload, read with the session's token). Throws an [ApiError].
  Future<Uint8List> download(ServicePurchase p) => repository.downloadBytes(p.downloadUrl!);

  // --- programmes and plans ----------------------------------------------------

  Future<String?> cancelTerm(PlanTerm t, {String? reason}) => _act(() async {
    await repository.cancelPlanTerm(t.id, reason: reason);
    await terms.load();
  });

  /// Pays for a programme the mentor accepted. Throws the API's refusal as an [ApiError].
  Future<PaymentOutcome> payTerm(PlanTerm t) async {
    final outcome = await repository.payPlanTerm(t);
    if (outcome.completed) await Future.wait([terms.load(), purchases.load()]);
    return outcome;
  }

  // --- cohorts and group seats ---------------------------------------------------

  Future<String?> withdrawEnrolment(ProgrammeEnrolment e) => _act(() async {
    await repository.withdrawEnrolment(e.id);
    await enrolments.load();
  });

  Future<String?> leaveSeat(GroupSession s) => _act(() async {
    await repository.leaveGroup(s.id);
    await seats.load();
  });
}
