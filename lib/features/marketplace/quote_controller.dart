import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import 'catalog_models.dart';
import 'marketplace_models.dart';
import 'marketplace_repository.dart';
import 'quote_models.dart';

/// The state of the request-a-quote sheet: what the member typed, what is wrong
/// with it, and the answer. Typed text lives here (not in the sheet), so a
/// refusal never costs the member what they wrote.
class QuoteController extends ChangeNotifier {
  QuoteController({
    required this.repository,
    required this.supplier,
    CatalogService? service,
    this.product,
    List<CatalogService>? services,
  }) : _service = service,
       _options = services,
       quantity = TextEditingController(text: '1');

  final MarketplaceRepository repository;
  final Supplier supplier;

  /// The product asked about, if the request is for one.
  final CatalogProduct? product;

  final scope = TextEditingController();
  final notes = TextEditingController();
  final TextEditingController quantity;
  final phone = TextEditingController();

  CatalogService? _service;
  List<CatalogService>? _options;
  QuoteTimeline _timeline = QuoteTimeline.immediate;
  bool? _needsPhone;
  bool _sending = false;
  bool _needsCompany = false;

  /// The company the person acts for (null: none, or not known). A member of one, in a role that does not post, is
  /// not helped by founding another; and a company cannot ask its own listing for a quote.
  String? _myCompanyId;
  String? _error;
  String? _quantityProblem;
  String? _phoneProblem;
  QuoteSent? _sent;
  bool _disposed = false;

  /// The service the request names (null: a general enquiry to the supplier).
  CatalogService? get service => _service;

  /// The supplier's services to choose from, once known (null while they load).
  List<CatalogService>? get options => _options;
  QuoteTimeline get timeline => _timeline;

  /// Whether to ask for the member's own mobile: their profile has none.
  bool get needsPhone => _needsPhone ?? false;
  bool get sending => _sending;

  /// The API's own refusal, or what is wrong with a field, for the line above the button.
  String? get error => _error;

  /// The refusal is for want of a company (a requirement is a company's): the form offers "Create a company".
  bool get needsCompany => _needsCompany;
  String? get quantityProblem => _quantityProblem;
  String? get phoneProblem => _phoneProblem;

  /// Set once the request was sent.
  QuoteSent? get sent => _sent;

  @override
  void dispose() {
    _disposed = true;
    scope.dispose();
    notes.dispose();
    quantity.dispose();
    phone.dispose();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Reads what the form needs: whether to ask for a number, and the supplier's
  /// services for the dropdown. A part that cannot be read is left out: the API
  /// decides when the request is sent.
  Future<void> load() async {
    await Future.wait([
      repository.hasPhone().then((has) => _needsPhone = !has).catchError((_) => false),
      repository.myCompanyId().then((id) => _myCompanyId = id).catchError((_) => null),
      if (_options == null && product == null)
        repository
            .servicesOf(supplier.companyId)
            .then((rows) => _options = rows)
            .catchError((_) => _options = const <CatalogService>[]),
    ]);
    _notify();
  }

  void pickService(CatalogService? service) {
    _service = service;
    _notify();
  }

  void pickTimeline(QuoteTimeline timeline) {
    _timeline = timeline;
    _notify();
  }

  /// The request as it would be sent.
  QuoteRequest build() => QuoteRequest(
    vendorId: supplier.id,
    supplierName: supplier.name,
    service: _service,
    product: product,
    scope: scope.text,
    timeline: _timeline,
    notes: notes.text,
    quantity: product == null ? null : int.tryParse(quantity.text.trim()),
    phone: needsPhone ? phone.text : null,
  );

  /// Checks what the API would, then sends. True when sent; otherwise [error] says why.
  Future<bool> submit() async {
    if (_sending) return false;
    _quantityProblem = product == null ? null : quantityIssue(quantity.text);
    _phoneProblem = needsPhone ? mobileIssue(phone.text) : null;
    _error = null;
    _needsCompany = false;
    if (_quantityProblem != null || _phoneProblem != null) {
      _notify();
      return false;
    }
    _sending = true;
    _notify();
    try {
      _sent = await repository.requestQuote(build());
      return true;
    } catch (e) {
      final failure = ApiError.from(e);
      _error = _worded(
        failure,
        hasCompany: _myCompanyId != null,
        ownListing: _myCompanyId != null && _myCompanyId == supplier.companyId,
      );
      _needsCompany = refusedForWantOfCompany(failure) && _myCompanyId == null;
      // The API asks for a number the profile lacks (or one it cannot read): show the field.
      if (failure.statusCode == 400 && RegExp('mobile number|phone', caseSensitive: false).hasMatch(failure.message)) {
        _needsPhone = true;
      }
      return false;
    } finally {
      _sending = false;
      _notify();
    }
  }

  /// Whether the API turned the request away because the person has no company to post for: a buyer acting as
  /// themselves ("Requirements are posted for a company. Register your company...") or a professional, whose role
  /// the endpoint does not take ("Insufficient role permissions"). Both are put right by founding a company page.
  static bool refusedForWantOfCompany(ApiError e) {
    if (e.statusCode != 403) return false;
    final said = e.message.trim().toLowerCase();
    return said.isEmpty ||
        said.contains('forbidden') ||
        said.contains('insufficient role') ||
        said.contains('register your company') ||
        said.contains('posted for a company');
  }

  /// A refusal for a member who may not post requirements says what to do about it: the API's own sentence when
  /// it already does ("Requirements are posted for a company. Register your company..."), else ours.
  static String _worded(ApiError e, {bool hasCompany = false, bool ownListing = false}) {
    // The API answers a company's request to its own listing with "No valid companies to invite.".
    if (ownListing && e.statusCode == 400 && e.message.toLowerCase().contains('no valid companies')) {
      return "This is your own company's listing: a company cannot ask itself for a quote.";
    }
    if (e.statusCode == 403) {
      final said = e.message.trim();
      // A member of a company whose role does not post (an office admin, a recruiter, a hiring manager) has a
      // company already: founding another is not the way, a colleague who posts is.
      final hint = hasCompany
          ? "Only a company's admins and buyers can ask suppliers for quotes. Ask your company's admin to send this one."
          : 'Only a company can ask suppliers for quotes. Create a company page on ICR first.';
      final lower = said.toLowerCase();
      return said.isEmpty || lower.contains('forbidden') || lower.contains('insufficient role') ? hint : said;
    }
    return e.message;
  }
}
