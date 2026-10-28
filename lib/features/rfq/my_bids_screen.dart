import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import 'rfq_links.dart';
import 'rfq_models.dart';
import 'rfq_navigation.dart';
import 'rfq_repository.dart';
import 'rfq_scope.dart';
import 'rfq_styles.dart';
import 'supplier_controllers.dart';
import 'widgets/rfq_widgets.dart';
import 'widgets/supplier_parts.dart';

/// "My Bids": what the supplier sent, by where it stands (Submitted,
/// Shortlisted, Won, Archived), each with its price, lead time and the
/// requirement behind it. A quote cannot be changed or withdrawn through the
/// API yet (`docs/backend-requests/rfq.md`), so "Message buyer" is how: it
/// opens the thread with the buyer.
class MyBidsScreen extends StatefulWidget {
  const MyBidsScreen({
    super.key,
    this.repository,
    this.links,
    this.onBack,
    this.onBell,
    this.onOpenConversation,
    this.onOpenSupplier,
  });

  final RfqRepository? repository;
  final RfqLinks? links;
  final VoidCallback? onBack;

  /// The bell; by default it opens the requirement alerts.
  final VoidCallback? onBell;
  final ValueChanged<String>? onOpenConversation;
  final ValueChanged<String>? onOpenSupplier;

  @override
  State<MyBidsScreen> createState() => _MyBidsScreenState();
}

class _MyBidsScreenState extends State<MyBidsScreen> {
  late final RfqHooks _hooks;
  late final MyBidsController _bids;
  String? _messaging;

  @override
  void initState() {
    super.initState();
    _hooks = rfqHooksFor(
      context,
      repository: widget.repository,
      links: widget.links,
      onOpenConversation: widget.onOpenConversation,
      onOpenSupplier: widget.onOpenSupplier,
    );
    _bids = MyBidsController(_hooks.repository)..start();
  }

  @override
  void dispose() {
    _bids.dispose();
    super.dispose();
  }

  Future<void> _open(String rfqId) async {
    await pushOpportunity(context, _hooks, rfqId);
    if (mounted) await _bids.refresh();
  }

  Future<void> _message(MyBid bid) async {
    if (_messaging != null) return;
    setState(() => _messaging = bid.id);
    final result = await _bids.messageBuyer(bid.rfqId);
    if (!mounted) return;
    setState(() => _messaging = null);
    if (result.id != null) {
      await _hooks.openConversation(context, result.id!);
    } else if (result.error != null) {
      showMessage(context, result.error!);
    }
  }

  Future<void> _startSelling() async {
    final message = await _bids.startSellingAndReload();
    if (message != null && mounted) showMessage(context, message);
  }

  bool get _anyBids => BidsTab.values.any((t) => _bids.bidsIn(t).isNotEmpty) || _bids.declinedInvites.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _bids,
      builder: (context, _) => RfqScaffold(
        title: 'My Bids',
        onBack: widget.onBack ?? () => Navigator.maybePop(context),
        unread: _bids.unread,
        onBell: widget.onBell ?? () => pushAlerts(context, _hooks),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _bids.refresh,
          child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: _slivers()),
        ),
      ),
    );
  }

  List<Widget> _slivers() {
    final b = _bids;
    Widget fill(Widget child) => SliverFillRemaining(hasScrollBody: false, child: child);
    if (b.loading && !_anyBids && b.gate == null) return [fill(const RfqSpinner())];
    if (b.error != null && !_anyBids) {
      return [
        fill(
          RfqNotice(
            icon: LucideIcons.cloudOff,
            title: "Couldn't load your bids",
            body: b.error,
            action: 'Try again',
            onAction: b.refresh,
          ),
        ),
      ];
    }
    final gate = b.gate;
    if (gate != null) {
      return [fill(SupplierGateView(gate: gate, what: 'bid on requirements', onStartSelling: _startSelling))];
    }
    final rows = b.bidsIn(b.tab);
    final declined = b.tab == BidsTab.archived ? b.declinedInvites : const <Requirement>[];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: PillTabs<BidsTab>(
            values: BidsTab.values,
            selected: b.tab,
            labelOf: (t) => t.label,
            countOf: b.count,
            onSelect: b.setTab,
          ),
        ),
      ),
      if (rows.isEmpty && declined.isEmpty)
        SliverFillRemaining(hasScrollBody: false, child: _empty(b.tab))
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList.separated(
            itemCount: rows.length + declined.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i >= rows.length) return _declinedTile(declined[i - rows.length]);
              final bid = rows[i];
              return MyBidCard(
                key: ValueKey('bid-${bid.id}'),
                bid: bid,
                busy: _messaging == bid.id,
                onOpen: () => _open(bid.rfqId),
                onMessage: () => _message(bid),
              );
            },
          ),
        ),
    ];
  }

  Widget _empty(BidsTab tab) {
    final (icon, title, body) = switch (tab) {
      BidsTab.submitted => (
        LucideIcons.send,
        'No bids waiting',
        'Quotes you send show here until the buyer shortlists or decides. Find work on the open board.',
      ),
      BidsTab.shortlisted => (
        LucideIcons.star,
        'Nothing shortlisted yet',
        'When a buyer shortlists your quote it moves here.',
      ),
      BidsTab.awarded => (LucideIcons.trophy, 'No wins yet', 'Awarded bids, with their purchase order, show here.'),
      BidsTab.archived => (
        LucideIcons.archive,
        'Nothing archived',
        'Bids that were not selected, and requirements that closed, are kept here.',
      ),
    };
    return RfqNotice(
      icon: icon,
      title: title,
      body: body,
      action: tab == BidsTab.submitted ? 'Find work' : null,
      onAction: tab == BidsTab.submitted ? () => pushBoard(context, _hooks) : null,
    );
  }

  Widget _declinedTile(Requirement r) => RfqCard(
    key: ValueKey('declined-${r.id}'),
    onTap: () => _open(r.id),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Row(
      children: [
        LogoTile(name: r.buyer?.displayName ?? r.title, logoUrl: r.buyer?.logoUrl, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.title, style: RfqText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('You declined this invitation', style: RfqText.small),
            ],
          ),
        ),
        const TonePill('Declined'),
      ],
    ),
  );
}
