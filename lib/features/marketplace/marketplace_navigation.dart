import 'package:flutter/material.dart';

import '../account/companies/create_company_screen.dart';
import 'catalog_models.dart';
import 'marketplace_links.dart';
import 'marketplace_models.dart';
import 'catalog_pages.dart';
import 'widgets/request_quote_sheet.dart';

/// Where the Marketplace hands over to the rest of the app. The lead wires the
/// callbacks in `lib/app.dart`; until a callback is given, each falls back to
/// the same page on the website, so a tap is never dead.
class MarketplaceNavigation {
  const MarketplaceNavigation({
    this.onRequestQuote,
    this.onMessage,
    this.onPostRfq,
    this.onMyRfqs,
    this.onAlerts,
    this.onNotifications,
    this.onOpenProduct,
    this.onOpenService,
    this.onOpenRfq,
    this.onOpenSupplier,
    this.onOpenConversation,
    this.onCreateCompany,
  });

  /// Nothing wired: every hand-over opens the website.
  static const none = MarketplaceNavigation();

  /// "Request for Quote (RFQ)" on a supplier, and "Get Quote" / "Book" on one of
  /// its services or products. Left out, the Marketplace shows its own quote form
  /// (a private requirement addressed to the supplier, `POST /rfq`); wire it to
  /// open the app's own requirement composer instead.
  final void Function(Supplier supplier, {CatalogService? service, CatalogProduct? product})? onRequestQuote;

  /// The message icon beside the quote button: a conversation with the supplier.
  final ValueChanged<Supplier>? onMessage;

  /// The "Post RFQ" chip.
  final VoidCallback? onPostRfq;

  /// The "My RFQ's" chip.
  final VoidCallback? onMyRfqs;

  /// The "Alerts" chip.
  final VoidCallback? onAlerts;

  /// The bell.
  final VoidCallback? onNotifications;

  /// A product, by its id (a supplier's product row, a search hit).
  final ValueChanged<String>? onOpenProduct;

  /// A service, by its id.
  final ValueChanged<String>? onOpenService;

  /// A requirement, by its id (a search hit).
  final ValueChanged<String>? onOpenRfq;

  /// Another supplier's profile, by its listing id (a product's supplier).
  final ValueChanged<String>? onOpenSupplier;

  /// A conversation's thread, by its id: where the app's own "Message" ends up
  /// once [onMessage] is not wired (the Marketplace starts the thread through
  /// `POST /messaging/conversations/supplier` and hands over its id).
  final ValueChanged<String>? onOpenConversation;

  /// Founding a company: where the quote form leads a person with no company (a requirement is a company's).
  /// Left out, the app's own "Create a company" page opens over the form, never the website.
  final VoidCallback? onCreateCompany;

  /// The same hand-overs with [other]'s where this one has none.
  MarketplaceNavigation merge(MarketplaceNavigation other) => MarketplaceNavigation(
    onRequestQuote: onRequestQuote ?? other.onRequestQuote,
    onMessage: onMessage ?? other.onMessage,
    onPostRfq: onPostRfq ?? other.onPostRfq,
    onMyRfqs: onMyRfqs ?? other.onMyRfqs,
    onAlerts: onAlerts ?? other.onAlerts,
    onNotifications: onNotifications ?? other.onNotifications,
    onOpenProduct: onOpenProduct ?? other.onOpenProduct,
    onOpenService: onOpenService ?? other.onOpenService,
    onOpenRfq: onOpenRfq ?? other.onOpenRfq,
    onOpenSupplier: onOpenSupplier ?? other.onOpenSupplier,
    onOpenConversation: onOpenConversation ?? other.onOpenConversation,
    onCreateCompany: onCreateCompany ?? other.onCreateCompany,
  );

  Future<void> postRfq(BuildContext context, MarketplaceLinks links) async {
    final open = onPostRfq;
    if (open != null) return open();
    await links.openSite(context, '/quote');
  }

  Future<void> myRfqs(BuildContext context, MarketplaceLinks links) async {
    final open = onMyRfqs;
    if (open != null) return open();
    await links.openSite(context, '/manage/requirements');
  }

  Future<void> alerts(BuildContext context, MarketplaceLinks links) async {
    final open = onAlerts;
    if (open != null) return open();
    await links.openSite(context, '/manage/requirements');
  }

  Future<void> notifications(BuildContext context, MarketplaceLinks links) async {
    final open = onNotifications;
    if (open != null) return open();
    await links.openSite(context, '/notifications');
  }

  Future<void> requestQuote(
    BuildContext context,
    MarketplaceLinks links,
    Supplier supplier, {
    CatalogService? service,
    CatalogProduct? product,
  }) async {
    final open = onRequestQuote;
    if (open != null) return open(supplier, service: service, product: product);
    // Nothing wired: the Marketplace's own form (the website's profile card, as a sheet).
    await showRequestQuoteSheet(context, supplier, service: service, product: product);
  }

  Future<void> message(BuildContext context, MarketplaceLinks links, Supplier supplier) async {
    final open = onMessage;
    if (open != null) return open(supplier);
    await links.openSite(context, '/messaging');
  }

  /// A service: the lead's page, else the Marketplace's own ([seed] is the row that was tapped).
  Future<void> openService(BuildContext context, MarketplaceLinks links, String id, {CatalogService? seed}) async {
    final open = onOpenService;
    if (open != null) return open(id);
    await showServicePage(context, id, seed: seed);
  }

  /// A product: the lead's page, else the Marketplace's own.
  Future<void> openProduct(BuildContext context, MarketplaceLinks links, String id, {CatalogProduct? seed}) async {
    final open = onOpenProduct;
    if (open != null) return open(id);
    await showProductPage(context, id, seed: seed);
  }

  /// "Create a company": the lead's screen, else the app's own page for founding one.
  Future<void> createCompany(BuildContext context) async {
    final open = onCreateCompany;
    if (open != null) return open();
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const CreateCompanyScreen()));
  }

  Future<void> openRfq(BuildContext context, MarketplaceLinks links, String id) async {
    final open = onOpenRfq;
    if (open != null) return open(id);
    await links.openSite(context, '/rfq/${Uri.encodeComponent(id)}');
  }
}

/// Hands a [MarketplaceNavigation] and the links down a screen, so a sheet
/// opened from anywhere in it takes the same hand-overs with it.
class MarketplaceScope extends InheritedWidget {
  const MarketplaceScope({super.key, required this.navigation, required this.links, required super.child});

  final MarketplaceNavigation navigation;
  final MarketplaceLinks links;

  static MarketplaceScope? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<MarketplaceScope>();

  /// The nearest scope's navigation, else [MarketplaceNavigation.none].
  static MarketplaceNavigation navigationOf(BuildContext context) =>
      maybeOf(context)?.navigation ?? MarketplaceNavigation.none;

  /// The nearest scope's links, else the system's.
  static MarketplaceLinks linksOf(BuildContext context) => maybeOf(context)?.links ?? const SystemMarketplaceLinks();

  @override
  bool updateShouldNotify(MarketplaceScope oldWidget) => navigation != oldWidget.navigation || links != oldWidget.links;
}
