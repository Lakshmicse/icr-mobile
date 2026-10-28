import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/title_bar.dart';
import 'marketplace_controller.dart';
import 'marketplace_links.dart';
import 'marketplace_models.dart';
import 'marketplace_navigation.dart';
import 'supplier_sheet.dart';
import 'widgets/market_footer.dart';
import 'widgets/market_toolbar.dart';
import 'widgets/search_extras.dart';
import 'widgets/search_suggestions.dart';
import 'categories_screen.dart' show showSuppliersOf;
import 'widgets/supplier_card.dart';
import 'widgets/supplier_grid.dart';

/// The Marketplace tab: the suppliers' grid from the Marketplace design.
///
/// Reads its [MarketplaceController] from `Provider`. The hand-overs are the
/// constructor's callbacks (the lead wires them in `lib/app.dart`); one left
/// out opens the same page on the website, so a tap is never dead.
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({
    super.key,
    required this.onBack,
    this.onPostRfq,
    this.onMyRfqs,
    this.onRfqAlerts,
    this.onBell,
    this.onMessageSupplier,
    this.counts,
    this.navigation = MarketplaceNavigation.none,
    this.links = const SystemMarketplaceLinks(),
    this.forceColumns,
  });

  /// The arrow at the top left; the shell goes back to Home.
  final VoidCallback onBack;

  /// The "Post RFQ" chip: the requirement composer.
  final VoidCallback? onPostRfq;

  /// The "My RFQ's" chip: the member's requirements.
  final VoidCallback? onMyRfqs;

  /// The "Alerts" chip: the requirement alerts.
  final VoidCallback? onRfqAlerts;

  /// The bell: the notifications.
  final VoidCallback? onBell;

  /// "Message" on a supplier's profile, with the supplier's listing id. Left
  /// out, the Marketplace opens the conversation itself (`POST
  /// /messaging/conversations/supplier`) and hands its id to
  /// [MarketplaceNavigation.onOpenConversation], else the website's inbox.
  final ValueChanged<String>? onMessageSupplier;

  /// The numbers on "My RFQ's" and "Alerts"; left out, the Marketplace reads
  /// them from the API itself (`GET /rfq/mine/summary`, the unread requirement
  /// notifications).
  final Future<MarketplaceCounts> Function()? counts;

  /// The other hand-overs (a product, a service, a requirement...).
  final MarketplaceNavigation navigation;

  /// Where a call, a chat, a website and a share go (a test records them).
  final MarketplaceLinks links;

  /// Draws this many columns whatever the width (a test shows the tablet's three
  /// on the phone's frame).
  @visibleForTesting
  final int? forceColumns;

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _synced = '';

  /// What is typed in the box right now (the suggestions are for these words).
  String _typed = '';

  @override
  void initState() {
    super.initState();
    final market = context.read<MarketplaceController>();
    market.useCounts(widget.counts);
    if (!market.started) market.start();
    _synced = market.filters.search;
    _search.text = _synced;
    _typed = _synced;
    _focus.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(MarketplaceScreen old) {
    super.didUpdateWidget(old);
    if (old.counts != widget.counts) context.read<MarketplaceController>().useCounts(widget.counts);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.dispose();
    _search.dispose();
    super.dispose();
  }

  /// The box changed: after a pause, read the suppliers whose names match.
  void _typing(String words) {
    setState(() => _typed = words);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) context.read<MarketplaceController>().suggest(words);
    });
  }

  /// Words to search for: from the keyboard, the cross, or a suggestion.
  void _runSearch(String words) {
    final market = context.read<MarketplaceController>();
    _debounce?.cancel();
    _focus.unfocus();
    if (_search.text != words) _search.text = words;
    _typed = words;
    market.rememberSearch(words);
    market.setSearch(words);
  }

  MarketplaceNavigation get _navigation => MarketplaceNavigation(
    onPostRfq: widget.onPostRfq,
    onMyRfqs: widget.onMyRfqs,
    onAlerts: widget.onRfqAlerts,
    onNotifications: widget.onBell,
    onMessage: widget.onMessageSupplier == null ? null : (s) => widget.onMessageSupplier!(s.id),
  ).merge(widget.navigation);

  void _openSupplier(BuildContext context, Supplier supplier) => showSupplierSheet(context, supplier);

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketplaceController>();
    final nav = _navigation;
    // "Clear filters" (and any other change from outside the box) rewrites what the box shows.
    if (market.filters.search != _synced) {
      _synced = market.filters.search;
      if (_search.text.trim() != _synced) _search.text = _synced;
    }
    return MarketplaceScope(
      navigation: nav,
      links: widget.links,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned.fill(
                  top: TitleBar.height,
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: market.refresh,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: MarketToolbar(
                            searchController: _search,
                            focusNode: _focus,
                            onChanged: _typing,
                            onSearch: _runSearch,
                          ),
                        ),
                        if (_focus.hasFocus) _suggestions(market) else ..._body(context, market, nav),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Builder(
                    builder: (context) => TitleBar(
                      title: 'Marketplace',
                      onBack: widget.onBack,
                      unread: market.unread,
                      onBell: () => nav.notifications(context, widget.links),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The box has focus: what it suggests takes the place of the list.
  Widget _suggestions(MarketplaceController market) {
    return SliverToBoxAdapter(
      child: Builder(
        builder: (context) => SearchSuggestions(
          query: _typed,
          onSearch: _runSearch,
          onSupplier: (s) {
            _focus.unfocus();
            market.rememberSearch(s.name);
            showSupplierSheet(context, s);
          },
          onCategory: (node) {
            _focus.unfocus();
            showSuppliersOf(context, node.key);
          },
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, MarketplaceController market, MarketplaceNavigation nav) {
    final nothing = market.suppliers.isEmpty;
    final extras = market.extras;
    final searching = market.filters.search.isNotEmpty;
    if (market.loading && nothing) {
      return [
        SupplierGridSliver(
          count: 6,
          forceColumns: widget.forceColumns,
          cardAt: (context, i, scale) => SupplierCardSkeleton(scale: scale),
        ),
      ];
    }
    if (market.error != null && nothing) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Notice(
            title: "Couldn't load suppliers",
            body: market.error!,
            action: 'Try again',
            onAction: market.refresh,
          ),
        ),
      ];
    }
    return [
      if (searching && !extras.isEmpty)
        SliverToBoxAdapter(
          // A Builder: the page a row opens inherits the screen's hand-overs only from a context under its scope.
          child: Builder(
            builder: (context) => SearchExtrasSection(
              query: market.filters.search,
              extras: extras,
              onService: (s) => nav.openService(context, widget.links, s.id, seed: s),
              onRfq: (r) => nav.openRfq(context, widget.links, r.id),
            ),
          ),
        ),
      if (nothing)
        SliverFillRemaining(
          hasScrollBody: false,
          child: market.filters.savedOnly
              ? _Notice(
                  title: 'No saved suppliers yet',
                  body: 'Save a supplier from its profile and it will be here.',
                  action: 'Show all suppliers',
                  onAction: () => market.setFilters(market.filters.copyWith(savedOnly: false)),
                )
              : _Notice(
                  title: market.narrowed ? 'No suppliers match' : 'No suppliers listed yet',
                  body: market.narrowed
                      ? 'Try other words, or clear the filters.'
                      : 'Suppliers show up here as they join.',
                  action: market.narrowed ? 'Clear filters' : null,
                  onAction: market.narrowed ? market.clearFilters : null,
                ),
        )
      else ...[
        SupplierGridSliver(
          count: market.suppliers.length,
          forceColumns: widget.forceColumns,
          cardAt: (context, i, scale) {
            final supplier = market.suppliers[i];
            return SupplierCard(
              key: ValueKey('supplier-${supplier.id}'),
              supplier: supplier,
              scale: scale,
              title: supplier.categories.isEmpty ? null : market.categoryName(supplier.categories.first),
              onTap: () => _openSupplier(context, supplier),
            );
          },
        ),
        const SliverToBoxAdapter(child: MarketFooter()),
      ],
    ];
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body, this.action, this.onAction});

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.store, size: 36, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: AppText.postTitle.copyWith(fontSize: 16, height: 1.3)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: AppText.small),
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.outlineVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(action!, style: AppText.link),
            ),
          ],
        ],
      ),
    );
  }
}

/// Said when something the member did could not be done.
void showMartMessage(BuildContext context, String message) => showMessage(context, message);
