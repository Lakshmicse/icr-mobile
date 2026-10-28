import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/rfq/demo_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/rfq_links.dart';
import 'package:icr_mobile/features/rfq/rfq_models.dart';

/// A link seam that remembers where a tap would have gone.
class RecordingRfqLinks extends RfqLinks {
  RecordingRfqLinks({this.opens = true});

  final bool opens;
  final List<Uri> opened = [];

  /// The files handed to the phone's viewers: path and name.
  final List<(String, String)> shared = [];

  /// What the file picker answers next (the phone's files the person "chose").
  List<PickedRfqFile> toPick = [];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return opens;
  }

  @override
  Future<bool> shareFile(String path, String name) async {
    shared.add((path, name));
    return opens;
  }

  @override
  Future<List<PickedRfqFile>> pickFiles({bool images = false}) async {
    final files = toPick;
    toPick = [];
    return files;
  }
}

/// The sample repository with switches: every read can be made to fail, a
/// write can be refused with the API's own sentence, and every call is noted.
class FlakyRfqRepository extends DemoRfqRepository {
  FlakyRfqRepository({super.now});

  /// Every read throws while this is set.
  bool failReads = false;

  /// The next write (any of them) answers this refusal, once.
  String? refuseNextWrite;
  int refuseStatus = 400;
  final List<String> calls = [];

  Future<T> _read<T>(String name, Future<T> Function() f) {
    calls.add(name);
    if (failReads) return Future.error(ApiError('The server said no.', statusCode: 500));
    return f();
  }

  Future<T> _write<T>(String name, Future<T> Function() f) {
    calls.add(name);
    final refusal = refuseNextWrite;
    if (refusal != null) {
      refuseNextWrite = null;
      return Future.error(ApiError(refusal, statusCode: refuseStatus));
    }
    return f();
  }

  @override
  Future<List<RfqAlert>> alerts({bool unreadOnly = false}) =>
      _read('alerts', () => super.alerts(unreadOnly: unreadOnly));

  @override
  Future<void> markAlertRead(String id) => _write('markAlertRead', () => super.markAlertRead(id));

  /// The API has the calls to change and withdraw a bid (it has not yet: the buttons are drawn only while it does).
  bool bidChanges = true;

  @override
  bool get supportsBidChanges => bidChanges;

  /// Who is asking cannot be read.
  bool failMe = false;

  @override
  Future<Poster> me() => _read('me', () => failMe ? Future<Poster>.error(ApiError('The server said no.', statusCode: 500)) : super.me());

  /// The buyer's list answers 403 (an account whose role does not post requirements).
  bool forbidMine = false;

  /// The buyer has posted nothing at all.
  bool emptyMine = false;

  @override
  Future<RequirementsSummary> summary() => _read(
    'summary',
    () => forbidMine
        ? Future<RequirementsSummary>.error(ApiError('Insufficient role permissions', statusCode: 403))
        : emptyMine
        ? Future.value(const RequirementsSummary())
        : super.summary(),
  );

  @override
  Future<RequirementPage> mine({
    MyView view = MyView.all,
    String search = '',
    RfqKind? kind,
    MySort sort = MySort.updated,
    int page = 1,
  }) => _read(
    'mine',
    () => forbidMine
        ? Future<RequirementPage>.error(ApiError('Insufficient role permissions', statusCode: 403))
        : emptyMine
        ? Future.value(const RequirementPage(rows: [], total: 0, hasMore: false))
        : super.mine(view: view, search: search, kind: kind, sort: sort, page: page),
  );

  /// `GET /rfq/:id` answers this error (an early-access 403, a 404) instead of the requirement.
  ApiError? requirementError;

  @override
  Future<Requirement> requirement(String id) => _read(
    'requirement',
    () => requirementError != null ? Future<Requirement>.error(requirementError!) : super.requirement(id),
  );

  /// `GET /rfq/:id/bids` is refused: the requirement is not the caller's.
  bool forbidBids = false;

  @override
  Future<List<Bid>> bids(String rfqId) => _read(
    'bids',
    () => forbidBids
        ? Future<List<Bid>>.error(ApiError('You can only modify your own requirements.', statusCode: 403))
        : super.bids(rfqId),
  );

  @override
  Future<List<SupplierInvite>> invite(String rfqId, List<String> vendorIds) =>
      _write('invite', () => super.invite(rfqId, vendorIds));

  @override
  Future<void> setStage(String id, RfqStage stage) => _write('setStage', () => super.setStage(id, stage));

  @override
  Future<void> screen(String rfqId, String vendorId, PreQualStatus status) =>
      _write('screen', () => super.screen(rfqId, vendorId, status));

  @override
  Future<void> shortlist(String rfqId, List<String> vendorIds) =>
      _write('shortlist', () => super.shortlist(rfqId, vendorIds));

  @override
  Future<void> deleteDraft(String id) => _write('deleteDraft', () => super.deleteDraft(id));

  @override
  Future<String> openConversation(String rfqId, {String? supplierCompanyId}) =>
      _write('openConversation', () => super.openConversation(rfqId, supplierCompanyId: supplierCompanyId));

  @override
  Future<BuyerContact> revealContact(String rfqId) => _write('revealContact', () => super.revealContact(rfqId));

  @override
  Future<void> startSelling(String companyId) => _write('startSelling', () => super.startSelling(companyId));

  @override
  Future<void> submitPreQual(String rfqId, Map<String, dynamic> body) => _write('submitPreQual', () {
    prequalSent.add((rfqId, body));
    return super.submitPreQual(rfqId, body);
  });

  @override
  Future<String> saveFile(RfqFile file) => _write('saveFile', () => super.saveFile(file));

  /// What was sent to change a bid, in order, and the requirements whose bid was withdrawn.
  final List<(String, Map<String, dynamic>)> bidChangesSent = [];
  final List<String> withdrawn = [];

  @override
  Future<MyBid> updateBid(String rfqId, Map<String, dynamic> body) => _write('updateBid', () {
    bidChangesSent.add((rfqId, body));
    return super.updateBid(rfqId, body);
  });

  @override
  Future<void> withdrawBid(String rfqId) => _write('withdrawBid', () {
    withdrawn.add(rfqId);
    return super.withdrawBid(rfqId);
  });

  /// What a requirement read told the API its reader saw: `(side, id)`.
  final List<(AlertSide, String)> seen = [];

  @override
  Future<void> markSeen(AlertSide side, String rfqId) {
    seen.add((side, rfqId));
    return super.markSeen(side, rfqId);
  }

  /// What `GET /vendors/me/access` answers instead of the sample access (a 403 for a buyer's account).
  ApiError? accessError;

  @override
  Future<VendorAccess> access() =>
      _read('access', () => accessError != null ? Future<VendorAccess>.error(accessError!) : super.access());

  @override
  Future<List<Requirement>> openBoard(BoardQuery query, {int page = 1, int limit = 20}) =>
      _read('openBoard', () => super.openBoard(query, page: page, limit: limit));

  @override
  Future<List<MyBid>> myBids() => _read('myBids', super.myBids);

  @override
  Future<OpportunityContext> opportunity(String rfqId) => _read('opportunity', () => super.opportunity(rfqId));

  /// What was sent as a bid or reply, and as pre-qualification answers, in order.
  final List<(String, Map<String, dynamic>)> placed = [];
  final List<(String, Map<String, dynamic>)> prequalSent = [];

  @override
  Future<MyBid> placeBid(String rfqId, Map<String, dynamic> body) => _write('placeBid', () {
    placed.add((rfqId, body));
    return super.placeBid(rfqId, body);
  });

  /// What was sent to post a requirement, and to change one, in order.
  final List<Map<String, dynamic>> created = [];
  final List<(String, Map<String, dynamic>)> patched = [];

  @override
  Future<PostResult> create(Map<String, dynamic> body) => _write('create', () {
    created.add(body);
    return super.create(body);
  });

  @override
  Future<void> update(String id, Map<String, dynamic> patch) => _write('update', () {
    patched.add((id, patch));
    return super.update(id, patch);
  });

  /// The next upload is refused with this sentence, once.
  String? refuseNextUpload;

  /// The place search answers an error while this is set.
  bool failPlaceSearch = false;

  @override
  Future<RfqFile> uploadFile(PickedRfqFile file, {required String purpose}) => _write('uploadFile', () async {
    final refusal = refuseNextUpload;
    if (refusal != null) {
      refuseNextUpload = null;
      throw ApiError(refusal, statusCode: 400);
    }
    return super.uploadFile(file, purpose: purpose);
  });

  @override
  Future<List<RfqPlace>> searchPlaces(String query) =>
      failPlaceSearch ? Future.error(ApiError('Place search is down.', statusCode: 502)) : super.searchPlaces(query);

  @override
  Future<void> act(String id, RfqAction action) => _write('act', () => super.act(id, action));

  @override
  Future<void> triageBid(String rfqId, String bidId, BidStatus status) =>
      _write('triageBid', () => super.triageBid(rfqId, bidId, status));

  @override
  Future<String?> award(String rfqId, String bidId) => _write('award', () => super.award(rfqId, bidId));

  @override
  Future<void> declineInvite(String rfqId) => _write('declineInvite', () => super.declineInvite(rfqId));
}

/// A phone-sized window, restored after the test.
void phoneWindow(WidgetTester tester, {Size size = const Size(390, 900)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Lets futures that complete at once settle, a few frames.
Future<void> settle(WidgetTester tester, [int frames = 4]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// [screen] in an app with the app's theme.
Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
  phoneWindow(tester);
  await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: screen));
  await settle(tester);
}
