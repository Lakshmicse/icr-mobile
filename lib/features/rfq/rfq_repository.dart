import 'rfq_links.dart' show PickedRfqFile;
import 'rfq_models.dart';

/// Where the requirements screens get their data: the API, or sample content
/// that matches the Marketplace design. Every method throws an `ApiError`
/// (or anything `ApiError.from` reads) when the API refuses.
abstract class RfqRepository {
  // ---- Who is asking ----------------------------------------------------------

  /// The signed-in person and the company they act for.
  Future<Poster> me();

  // ---- The buyer's requirements -------------------------------------------------

  /// The counts on the tabs and tiles, and the action items (`GET /rfq/mine/summary`).
  Future<RequirementsSummary> summary();

  /// One page of the buyer's requirements (`GET /rfq/mine`).
  Future<RequirementPage> mine({
    MyView view = MyView.all,
    String search = '',
    RfqKind? kind,
    MySort sort = MySort.updated,
    int page = 1,
  });

  /// One requirement, as its reader may see it (`GET /rfq/:id`).
  Future<Requirement> requirement(String id);

  /// Posts a requirement (`POST /rfq`).
  Future<PostResult> create(Map<String, dynamic> body);

  /// Edits one (`PATCH /rfq/:id`).
  Future<void> update(String id, Map<String, dynamic> patch);

  /// Publish, close or cancel (`POST /rfq/:id/publish|close|cancel`).
  Future<void> act(String id, RfqAction action);

  /// Deletes a draft (`DELETE /rfq/:id`); only a draft is offered this.
  Future<void> deleteDraft(String id);

  /// Moves a staged RFQ on (`POST /rfq/:id/stage`).
  Future<void> setStage(String id, RfqStage stage);

  // ---- Responses, for the owner -------------------------------------------------

  Future<List<Bid>> bids(String rfqId);

  /// Shortlist, decline or put back to new (`PATCH /rfq/:id/bids/:bidId`).
  Future<void> triageBid(String rfqId, String bidId, BidStatus status);

  /// Awards a bid (an RFQ raises a purchase order, whose number comes back) or
  /// selects an enquiry's reply (`POST /rfq/:id/bids/:bidId/award`).
  Future<String?> award(String rfqId, String bidId);

  Future<List<PreQualResponse>> responses(String rfqId);

  /// Qualifies or rejects a pre-qualification response.
  Future<void> screen(String rfqId, String vendorId, PreQualStatus status);

  Future<void> shortlist(String rfqId, List<String> vendorIds);

  Future<List<SupplierInvite>> invites(String rfqId);

  /// Suppliers that fit and are not invited yet (`GET /rfq/:id/suggested-vendors`).
  Future<List<SupplierHit>> suggested(String rfqId);

  /// Suppliers by name (`GET /vendors?search=`).
  Future<List<SupplierHit>> findSuppliers(String query);

  Future<List<SupplierInvite>> invite(String rfqId, List<String> vendorIds);

  /// The owner's threads with suppliers about it (`GET /rfq/:id/conversations`).
  Future<List<SupplierThread>> threads(String rfqId);

  /// Opens (or finds) the thread about a requirement and returns its id: the
  /// owner names the supplier company; a supplier sends nothing.
  Future<String> openConversation(String rfqId, {String? supplierCompanyId});

  // ---- The supplier's side --------------------------------------------------------

  Future<VendorAccess> access();

  /// The open board (`GET /rfq/open`).
  Future<List<Requirement>> openBoard(BoardQuery query, {int page = 1, int limit = 20});

  /// Requirements the supplier was invited to (`GET /rfq/invited`).
  Future<List<Requirement>> invited();

  /// The supplier's own bids (`GET /rfq/bids/mine`).
  Future<List<MyBid>> myBids();

  /// Buyer, match and the supplier's own reply (`GET /rfq/:id/opportunity`).
  Future<OpportunityContext> opportunity(String rfqId);

  Future<MyBid> placeBid(String rfqId, Map<String, dynamic> body);

  /// Whether the API lets a supplier change or take back their own quote (`PATCH|DELETE /rfq/:id/bids/mine`, which
  /// the portal does not have yet: `docs/backend-requests/rfq.md`). The screens draw "Edit bid" and "Withdraw"
  /// only while this is true.
  bool get supportsBidChanges;

  /// Changes the supplier's own quote on a requirement that still takes responses.
  Future<MyBid> updateBid(String rfqId, Map<String, dynamic> body);

  /// Takes the supplier's own quote back (an invitation, if there was one, is open again).
  Future<void> withdrawBid(String rfqId);

  Future<void> declineInvite(String rfqId);

  Future<void> submitPreQual(String rfqId, Map<String, dynamic> body);

  /// The buyer's contact, once the supplier has bid and the plan shows it.
  Future<BuyerContact> revealContact(String rfqId);

  /// Starts selling: the company's supplier listing (`POST /vendors`).
  Future<void> startSelling(String companyId);

  // ---- Alerts and counts ------------------------------------------------------------

  /// Notifications about requirements, newest first.
  Future<List<RfqAlert>> alerts({bool unreadOnly = false});

  Future<void> markAlertRead(String id);

  /// The reader opened a requirement: what told them about it is read
  /// (`PATCH /notifications/seen`, kind `rfq.owner` or `rfq.supplier`).
  Future<void> markSeen(AlertSide side, String rfqId);

  /// Every unread notification, for the bell's dot.
  Future<int> unreadNotifications();

  /// "My RFQ's 3" and "Alerts 2 new".
  Future<RfqCounts> counts();

  // ---- The composer's lookups -----------------------------------------------------------

  /// The service taxonomy to two levels (`GET /categories/tree?kind=SERVICE`).
  Future<List<CategoryNode>> categories();

  /// A sub-category's specialisations (`GET /categories?parentId=`).
  Future<List<CategoryNode>> specialisations(String parentId);

  /// Places anywhere: ICR's city master first, then the world (`GET /locations/search?q=`), each with its
  /// own state and country.
  Future<List<RfqPlace>> searchPlaces(String query);

  /// Uploads a chosen file (`POST /uploads?purpose=`) and answers the stored record to attach to a
  /// requirement (`rfq-attachment`, public) or to a bid (`bid-attachment`, private).
  Future<RfqFile> uploadFile(PickedRfqFile file, {required String purpose});

  /// A private file (a supplier's quotation) fetched with the person's session and saved on the phone: its
  /// path, to hand to the phone's own viewers.
  Future<String> saveFile(RfqFile file);

  /// The name of a taxonomy key, once the taxonomy has loaded; null before.
  String? categoryName(String key);

  /// A page of the website, for what the app does not do.
  Uri sitePage(String path);
}
