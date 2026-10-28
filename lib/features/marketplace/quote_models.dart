import 'catalog_models.dart';

/// How soon the buyer wants it (the profile's "Target timeline").
enum QuoteTimeline {
  immediate('Immediate'),
  within30('Within 30 days'),
  amc('AMC contract');

  const QuoteTimeline(this.label);

  /// Written into the requirement's description, in English: the supplier reads it.
  final String label;
}

/// What a requirement's limits are (`REQUIREMENT_LIMITS` in `@icr/shared`, read by
/// `CreateRfqDto`), so the form refuses what the API would.
class QuoteLimits {
  QuoteLimits._();

  static const title = 200;
  static const description = 5000;
  static const maxQuantity = 1000000;
  static const unit = 40;

  /// The scope and the notes share the description with its two fixed lines.
  static const scope = 300;
  static const notes = 3000;
}

/// A quote request to one supplier: the same private ("targeted") requirement the
/// website's profile card and quote dialog create (`POST /rfq`).
class QuoteRequest {
  const QuoteRequest({
    required this.vendorId,
    required this.supplierName,
    this.service,
    this.product,
    this.scope = '',
    this.timeline = QuoteTimeline.immediate,
    this.notes = '',
    this.quantity,
    this.phone,
  });

  /// The supplier's listing id (`Vendor.id`).
  final String vendorId;
  final String supplierName;

  /// The service asked about; its name titles the requirement and its taxonomy keys
  /// go in the category fields (the API validates them, so free text never does).
  final CatalogService? service;

  /// The product asked about: the requirement's one line item.
  final CatalogProduct? product;
  final String scope;
  final QuoteTimeline timeline;
  final String notes;

  /// For a product, how many.
  final int? quantity;

  /// The sender's own mobile, sent only when the profile has none (the API saves it to the profile).
  final String? phone;

  /// "Drone Facade Cleaning — quote request". The title stays English: it is stored and the supplier reads it.
  String get title {
    final item = product?.name ?? service?.name;
    final text = item == null ? 'Quote request — $supplierName' : '$item — quote request';
    return text.length <= QuoteLimits.title ? text : text.substring(0, QuoteLimits.title);
  }

  String get description => [
    if (scope.trim().isNotEmpty) 'Scope: ${scope.trim()}',
    'Timeline: ${timeline.label}',
    if (notes.trim().isNotEmpty) notes.trim(),
  ].join('\n');

  /// The `POST /rfq` body.
  Map<String, dynamic> toJson() {
    final unit = product?.unit;
    return {
      'kind': 'ENQUIRY',
      'status': 'PUBLISHED',
      'visibility': 'TARGETED',
      'title': title,
      'description': description,
      if (service?.category != null) 'category': service!.category,
      if (service?.subcategory != null) 'subcategory': service!.subcategory,
      if (product != null)
        'items': [
          {
            'name': product!.name.length <= 200 ? product!.name : product!.name.substring(0, 200),
            'quantity': quantity ?? 1,
            if (unit != null && unit.length <= QuoteLimits.unit) 'unit': unit,
          },
        ],
      'vendorIds': [vendorId],
      if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
    };
  }
}

/// The requirement a quote request created.
class QuoteSent {
  const QuoteSent({required this.id, required this.title});

  final String id;
  final String title;
}

/// Why a typed quantity is refused (the API's rule: a whole number, one to a million), or null.
String? quantityIssue(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return 'Enter how many you need.';
  if (!RegExp(r'^\d+$').hasMatch(text)) return 'Enter a whole number.';
  final n = int.parse(text);
  if (n < 1 || n > QuoteLimits.maxQuantity) return 'Enter a number from 1 to ${_grouped(QuoteLimits.maxQuantity)}.';
  return null;
}

String _grouped(int n) {
  final digits = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Why a typed mobile number is refused before it is sent (at least eight digits); the API judges the rest.
String? mobileIssue(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (raw.trim().isEmpty) return 'Add a mobile number so the supplier can reach you.';
  if (digits.length < 8) return 'Enter a valid mobile number, with its country code if it is not Indian.';
  return null;
}
