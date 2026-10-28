import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_error.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/detail_sheet.dart';
import 'marketplace_controller.dart';
import 'marketplace_entry.dart';
import 'marketplace_links.dart';
import 'marketplace_models.dart';
import 'marketplace_navigation.dart';
import 'marketplace_repository.dart';
import 'marketplace_styles.dart';
import 'supplier_controller.dart';
import 'widgets/supplier_card.dart';
import 'widgets/supplier_catalog_tab.dart';
import 'widgets/supplier_overview_tab.dart';
import 'widgets/supplier_proofs_tab.dart';

/// Opens a supplier's profile over the Marketplace, as the Supplier Profile
/// designs: blurred and dimmed page behind, a handle, save and share, the
/// supplier's header, three tabs and "Request for Quote (RFQ)" pinned at the
/// foot. The list behind follows what the member does here (a bookmark, the
/// rating the API reads back); the hand-overs are the screen's
/// [MarketplaceScope].
///
/// Needs the Marketplace's [MarketplaceController] above [context]; from
/// anywhere else in the app use [showSupplierSheetById] or
/// [showSupplierSheetForCompany].
Future<void> showSupplierSheet(BuildContext context, Supplier supplier, {SupplierTab tab = SupplierTab.overview}) =>
    _presentSupplier(
      context,
      context.read<MarketplaceController>(),
      supplier,
      tab: tab,
      navigation: MarketplaceScope.navigationOf(context),
      links: MarketplaceScope.linksOf(context),
    );

Future<void> _presentSupplier(
  BuildContext context,
  MarketplaceController market,
  Supplier supplier, {
  required SupplierTab tab,
  required MarketplaceNavigation navigation,
  required MarketplaceLinks links,
}) async {
  final controller = SupplierController(
    repository: market.repository,
    seed: supplier,
    saved: market.isSaved(supplier.id),
    tab: tab,
    onSaved: market.markSaved,
    onLoaded: market.updateSupplier,
  )..load();
  await Navigator.of(context).push(
    BlurredSheetRoute<void>(
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => MarketplaceScope(
        navigation: navigation,
        links: links,
        child: ChangeNotifierProvider<MarketplaceController>.value(
          value: market,
          child: ChangeNotifierProvider<SupplierController>.value(
            value: controller,
            child: const SupplierSheetFrame(body: SupplierSheetBody(), bottomBar: SupplierSheetBar()),
          ),
        ),
      ),
    ),
  );
  controller.dispose();
}

/// A supplier's profile from anywhere in the app, by its listing id (the id
/// `GET /vendors` and a requirement's bids carry): reads the listing, then opens
/// the same sheet the Marketplace opens. A listing that cannot be read is said
/// so in a message, and nothing opens.
///
/// [navigation] and [links] are the hand-overs the sheet takes with it (inside the
/// Marketplace they come from its screen); [repository] defaults to the app's
/// ([marketplaceRepositoryOf]).
Future<void> showSupplierSheetById(
  BuildContext context,
  String vendorId, {
  SupplierTab tab = SupplierTab.overview,
  MarketplaceNavigation navigation = MarketplaceNavigation.none,
  MarketplaceLinks? links,
  MarketplaceRepository? repository,
}) => _openFromOutside(
  context,
  tab: tab,
  navigation: navigation,
  links: links,
  repository: repository,
  read: (repo) => repo.supplier(vendorId),
  missing: 'This supplier is no longer listed.',
);

/// A supplier's profile by its company's id (what a job, a team page or a
/// notification names): the company's supplier listing, when it has one. A company
/// that does not sell on ICR says so in a message.
Future<void> showSupplierSheetForCompany(
  BuildContext context,
  String companyId, {
  SupplierTab tab = SupplierTab.overview,
  MarketplaceNavigation navigation = MarketplaceNavigation.none,
  MarketplaceLinks? links,
  MarketplaceRepository? repository,
}) => _openFromOutside(
  context,
  tab: tab,
  navigation: navigation,
  links: links,
  repository: repository,
  read: (repo) => repo.supplierOfCompany(companyId),
  missing: 'This company has no supplier listing.',
);

Future<void> _openFromOutside(
  BuildContext context, {
  required SupplierTab tab,
  required MarketplaceNavigation navigation,
  required MarketplaceLinks? links,
  required MarketplaceRepository? repository,
  required Future<Supplier?> Function(MarketplaceRepository repository) read,
  required String missing,
}) async {
  final inside = Provider.of<MarketplaceController?>(context, listen: false);
  final repo = repository ?? marketplaceRepositoryOf(context);
  final market = inside != null && identical(inside.repository, repo) ? inside : MarketplaceController(repo);
  final scoped = MarketplaceScope.maybeOf(context);
  final nav = navigation.merge(scoped?.navigation ?? MarketplaceNavigation.none);
  final handOvers = links ?? scoped?.links ?? const SystemMarketplaceLinks();
  final messenger = ScaffoldMessenger.maybeOf(context);
  void say(String text) => messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Supplier? supplier;
  try {
    // The bookmark's state is read beside the listing, so the sheet opens marked right.
    final results = await Future.wait<Object?>([read(repo), if (!identical(market, inside)) market.loadSavedIds()]);
    supplier = results.first as Supplier?;
  } catch (e) {
    say(ApiError.from(e).message);
    if (!identical(market, inside)) market.dispose();
    return;
  }
  if (supplier == null) {
    say(missing);
    if (!identical(market, inside)) market.dispose();
    return;
  }
  if (!context.mounted) {
    if (!identical(market, inside)) market.dispose();
    return;
  }
  try {
    await _presentSupplier(context, market, supplier, tab: tab, navigation: nav, links: handOvers);
  } finally {
    if (!identical(market, inside)) market.dispose();
  }
}

/// The sheet's white panel: rounded top, a 1 dp edge, the handle, [body]
/// scrolling under it and [bottomBar] pinned at the foot.
class SupplierSheetFrame extends StatelessWidget {
  const SupplierSheetFrame({super.key, required this.body, required this.bottomBar, this.topInset = 72});

  final Widget body;
  final Widget bottomBar;

  /// How much of the page stays visible above the sheet.
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).top - topInset;
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: ColoredBox(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: body),
              bottomBar,
            ],
          ),
        ),
      ),
    );
  }
}

/// Everything above the bar: the handle and the save and share icons, then the
/// scrolling profile.
class SupplierSheetBody extends StatelessWidget {
  const SupplierSheetBody({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SupplierController>();
    final scope = MarketplaceScope.maybeOf(context);
    final links = scope?.links ?? const SystemMarketplaceLinks();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(
          saved: c.saved,
          onSave: () async {
            final message = await c.toggleSave();
            if (message != null && context.mounted) showMessage(context, message);
          },
          onShare: () => links.shareSupplier(c.supplier),
        ),
        Expanded(
          child: ListView(
            key: const ValueKey('supplier-scroll'),
            padding: EdgeInsets.zero,
            children: [
              SupplierHeader(supplier: c.supplier),
              const SizedBox(height: 11),
              const SupplierTabs(),
              switch (c.tab) {
                SupplierTab.overview => const SupplierOverviewTab(),
                SupplierTab.catalog => const SupplierCatalogTab(),
                SupplierTab.proofs => const SupplierProofsTab(),
              },
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

/// The handle, and the bookmark and share icons under it. 56 dp, as the design.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.saved, required this.onSave, required this.onShare});

  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 40,
                height: 5.5,
                decoration: BoxDecoration(color: MartColors.handle, borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ),
          Positioned(
            right: 12.5,
            top: 17,
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: saved ? 'Remove bookmark' : 'Save supplier',
                  child: InkResponse(
                    key: const ValueKey('supplier-save'),
                    onTap: onSave,
                    radius: 22,
                    child: SizedBox(
                      width: 40,
                      height: 36,
                      child: Icon(
                        saved ? Icons.bookmark : Icons.bookmark_border,
                        size: 23,
                        color: saved ? AppColors.primary : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Semantics(
                  button: true,
                  label: 'Share supplier',
                  child: InkResponse(
                    key: const ValueKey('supplier-share'),
                    onTap: onShare,
                    radius: 22,
                    child: const SizedBox(
                      width: 40,
                      height: 36,
                      child: Icon(Symbols.share, size: 20, color: AppColors.onSurfaceVariant, weight: 500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The supplier's header: logo, name with its seal, how it is incorporated, its
/// rating and tier, its pitch, and Call HQ / WhatsApp / Website.
class SupplierHeader extends StatelessWidget {
  const SupplierHeader({super.key, required this.supplier});

  final Supplier supplier;

  @override
  Widget build(BuildContext context) {
    final links = MarketplaceScope.linksOf(context);
    final s = supplier;
    final registration = s.registrationLine;
    final tier = s.level.tier;
    final phone = s.phone;
    final site = websiteUri(s.website);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border.symmetric(horizontal: BorderSide(color: MartColors.cardBorder, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 19, 16, 9.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LogoTile(supplier: s),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(s.name, style: MartText.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                        if (s.level.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(LucideIcons.badgeCheck, size: 16.8, color: AppColors.primary),
                        ],
                      ],
                    ),
                    if (registration != null) ...[
                      const SizedBox(height: 4.25),
                      Text(registration, style: MartText.registration, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 5.75),
                    _RatingLine(supplier: s, tier: tier),
                  ],
                ),
              ),
            ],
          ),
          if ((s.headline ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(s.headline!, style: MartText.tagline),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeaderButton(
                  key: const ValueKey('call-hq'),
                  icon: Symbols.call,
                  label: 'Call HQ',
                  style: MartText.callHq,
                  fill: AppColors.surfaceContainer,
                  iconSize: 16,
                  enabled: phone != null,
                  onTap: () => phone == null
                      ? showMessage(context, 'This supplier has not listed a phone number.')
                      : links.call(context, phone),
                ),
              ),
              const SizedBox(width: 10),
              _HeaderButton(
                key: const ValueKey('whatsapp'),
                icon: Icons.message_outlined,
                label: 'WhatsApp',
                style: MartText.whatsapp,
                iconSize: 12.5,
                iconColor: MartColors.whatsapp,
                enabled: phone != null,
                onTap: () => phone == null
                    ? showMessage(context, 'This supplier has not listed a phone number.')
                    : links.chat(context, phone, text: 'Hello ${s.name}, I found you on ICR Supplier Mart.'),
              ),
              const SizedBox(width: 19),
              _HeaderButton(
                key: const ValueKey('website'),
                icon: LucideIcons.archive,
                label: 'Website',
                style: MartText.website,
                iconSize: 11.5,
                iconColor: AppColors.primary,
                enabled: site != null,
                onTap: () => site == null
                    ? showMessage(context, 'This supplier has not listed a website.')
                    : links.openUri(context, site),
              ),
              const SizedBox(width: 8.75),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile({required this.supplier});

  final Supplier supplier;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: MartColors.logoTile,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      // The design leaves the tile a flat blue-grey; a supplier with a logo shows it.
      child: supplier.logoUrl == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(6),
              child: SupplierMark(supplier: supplier, maxWidth: 44, height: 44),
            ),
    );
  }
}

class _RatingLine extends StatelessWidget {
  const _RatingLine({required this.supplier, required this.tier});

  final Supplier supplier;
  final String? tier;

  @override
  Widget build(BuildContext context) {
    final s = supplier;
    Widget dot() => Container(
      width: 3.5,
      height: 3.5,
      margin: const EdgeInsets.only(left: 7.75, right: 6.5),
      decoration: const BoxDecoration(color: AppColors.outline, shape: BoxShape.circle),
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 2,
      children: [
        if (s.ratingCount > 0) ...[
          // 12 dp of ink: the glyph fills 80% of its box.
          const SizedBox(
            width: 12,
            height: 15,
            child: OverflowBox(
              maxWidth: 15,
              maxHeight: 15,
              child: Icon(Icons.star, size: 15, color: MartColors.profileStar),
            ),
          ),
          const SizedBox(width: 2),
          Text(s.ratingLabel, style: MartText.ratingValue),
          dot(),
          Text(s.reviewsLabel, style: MartText.ratingMeta),
        ] else
          Text('No ratings yet', style: MartText.ratingMeta),
        if (tier != null) ...[
          Container(
            width: 3.5,
            height: 3.5,
            margin: const EdgeInsets.only(left: 7, right: 5.5),
            decoration: const BoxDecoration(color: AppColors.outline, shape: BoxShape.circle),
          ),
          const Icon(LucideIcons.shieldCheck, size: 12.2, color: AppColors.tertiary),
          const SizedBox(width: 1.25),
          Text(tier!, style: MartText.tier),
        ],
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    super.key,
    required this.icon,
    required this.label,
    required this.style,
    required this.onTap,
    required this.iconSize,
    this.fill,
    this.iconColor,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final TextStyle style;
  final VoidCallback onTap;
  final double iconSize;
  final Color? fill;
  final Color? iconColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: fill ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            height: 26,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: fill == null ? 4 : 0),
              child: Row(
                // A filled button spreads over the room it is given; a bare one is as wide as its words.
                mainAxisSize: fill == null ? MainAxisSize.min : MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: iconSize, color: iconColor ?? style.color),
                  const SizedBox(width: 6),
                  if (fill == null)
                    Text(label, style: style, maxLines: 1)
                  else
                    Flexible(
                      child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Overview, Products & services, Compliances & Proofs.
class SupplierTabs extends StatelessWidget {
  const SupplierTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SupplierController>();
    return SizedBox(
      height: 29.5,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        children: [
          for (final (i, tab) in SupplierTab.values.indexed) ...[
            if (i > 0) const SizedBox(width: 6.5),
            _TabPill(key: ValueKey('tab-${tab.name}'), label: tab.label, on: c.tab == tab, onTap: () => c.select(tab)),
          ],
        ],
      ),
    );
  }
}

/// A tab: the open one is a blue pill (28.25 dp tall), the others a white one with a
/// hairline (29.5 dp), as the design draws them.
class _TabPill extends StatelessWidget {
  const _TabPill({super.key, required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(
      side: on ? BorderSide.none : const BorderSide(color: MartColors.cardBorder, width: 1.25),
    );
    return Semantics(
      button: true,
      selected: on,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: on ? 0.6 : 0),
        child: Material(
          color: on ? AppColors.primary : Colors.white,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.9),
              alignment: Alignment.center,
              child: Text(label, style: on ? MartText.tabOn : MartText.tab),
            ),
          ),
        ),
      ),
    );
  }
}

/// The message icon: the lead's conversation if it wired one, else the
/// Marketplace opens the thread itself (`POST /messaging/conversations/supplier`) and
/// hands its id over, else the website's inbox.
Future<void> _message(
  BuildContext context,
  SupplierController c,
  MarketplaceNavigation nav,
  MarketplaceLinks links,
) async {
  final wired = nav.onMessage;
  if (wired != null) return wired(c.supplier);
  final started = await c.startConversation();
  if (!context.mounted) return;
  final error = started.error;
  if (error != null) {
    showMessage(context, error);
    return;
  }
  final open = nav.onOpenConversation;
  if (open != null) return open(started.conversationId!);
  await links.openSite(context, '/messaging?c=${Uri.encodeQueryComponent(started.conversationId!)}');
}

/// "Request for Quote (RFQ)" and the message icon, pinned under the profile.
class SupplierSheetBar extends StatelessWidget {
  const SupplierSheetBar({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SupplierController>();
    final nav = MarketplaceScope.navigationOf(context);
    final links = MarketplaceScope.linksOf(context);
    return Container(
      decoration: const BoxDecoration(
        color: MartColors.barFill,
        border: Border(top: BorderSide(color: MartColors.cardBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Color(0x331D63A3), blurRadius: 8, offset: Offset(0, 3))],
                  ),
                  child: Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      key: const ValueKey('request-quote'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => nav.requestQuote(context, links, c.supplier),
                      child: SizedBox(
                        height: 41.75,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.zap, size: 14, color: Colors.white),
                            const SizedBox(width: 8),
                            Text('Request for Quote (RFQ)', style: MartText.rfqButton),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Message ${c.supplier.name}',
                child: InkResponse(
                  key: const ValueKey('message-supplier'),
                  onTap: () => _message(context, c, nav, links),
                  radius: 28,
                  child: const SizedBox(
                    width: 64,
                    height: 42,
                    child: Icon(Icons.message_outlined, size: 24, color: AppColors.tertiary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
