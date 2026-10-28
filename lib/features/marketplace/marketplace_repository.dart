import 'catalog_models.dart';
import 'marketplace_filters.dart';
import 'marketplace_models.dart';
import 'quote_models.dart';

/// A page of catalogue rows.
class CatalogPage<T> {
  const CatalogPage({required this.items, required this.total, required this.page, required this.hasMore});

  final List<T> items;
  final int total;
  final int page;
  final bool hasMore;
}

/// Where the Marketplace screens get their data: the API, or the design's
/// sample content. Every method throws an `ApiError` (or anything
/// `ApiError.from` reads) when the API refuses.
abstract class MarketplaceRepository {
  // ---- The directory --------------------------------------------------------------

  /// One page of suppliers for the search and filters (`GET /vendors`).
  Future<SupplierPage> suppliers(MarketplaceFilters filters, {int page = 1});

  /// The member's bookmarked suppliers, newest save first (`GET /vendors/saved`).
  Future<SupplierPage> savedSuppliers({int page = 1});

  /// The ids of the saved suppliers, to paint bookmarks (`GET /vendors/saved/ids`).
  Future<Set<String>> savedIds();

  /// Bookmarks a supplier, or takes the bookmark back
  /// (`POST|DELETE /vendors/:id/save`).
  Future<void> setSaved(String vendorId, bool saved);

  /// The cities suppliers are in (`GET /vendors/cities`).
  Future<List<String>> cities();

  /// The category tree to three levels, each node with its supplier count
  /// (`GET /categories/tree`, `GET /vendors/category-counts`).
  Future<List<CategoryNode>> categories();

  /// "My RFQ's 3" and "Alerts 2 new".
  Future<MarketplaceCounts> counts();

  /// Every unread notification, for the bell's dot.
  Future<int> unreadNotifications();

  /// Services and requirements the search words also match.
  Future<SearchExtras> searchExtras(String query);

  // ---- One supplier ----------------------------------------------------------------

  /// The full listing: offices, legal structure, ratings (`GET /vendors/:id`).
  Future<Supplier> supplier(String id);

  /// The listing of a company, when it has one (`GET /vendors?companyId=`).
  Future<Supplier?> supplierOfCompany(String companyId);

  /// What the company holds that ICR shows buyers (`GET /certifications/verified`).
  Future<List<Compliance>> compliances(String companyId);

  Future<List<CatalogService>> servicesOf(String companyId);

  Future<List<CatalogProduct>> productsOf(String companyId);

  /// Opens a conversation with the supplier's team and returns its id
  /// (`POST /messaging/conversations/supplier`; the API picks who receives it,
  /// and refuses a listing with nobody to).
  Future<String> startConversation(String vendorId, {String? message});

  /// Rates a supplier, or replaces the member's rating (`POST /vendors/:id/ratings`).
  Future<void> rate(String vendorId, {required int score, String? comment});

  // ---- The catalogue -----------------------------------------------------------------

  Future<CatalogProduct> product(String id);

  Future<CatalogService> service(String id);

  /// A page of products, narrowed by category slug, supplier or words (`GET /products`).
  Future<CatalogPage<CatalogProduct>> products({
    String? categorySlug,
    String? companyId,
    String search = '',
    int page = 1,
  });

  /// A page of services, narrowed by category key, supplier or words (`GET /services`).
  Future<CatalogPage<CatalogService>> services({String? category, String? companyId, String search = '', int page = 1});

  // ---- Asking for a quote ----------------------------------------------------------------

  /// Whether the signed-in member has a mobile number on their profile (`GET /auth/me`):
  /// a supplier answers by phone too, so a request without one asks for it.
  Future<bool> hasPhone();

  /// The company the signed-in person acts for; null when they act for none or the source cannot tell (a refusal is
  /// then worded to fit both).
  Future<String?> myCompanyId() async => null;

  /// Sends the supplier a private quote request: a targeted enquiry that goes out now
  /// (`POST /rfq`). Throws what the API refuses (a member who may not post requirements,
  /// a missing phone, the supplier's own listing).
  Future<QuoteSent> requestQuote(QuoteRequest request);

  /// A page of the website, for what the app does not do.
  Uri sitePage(String path);
}
