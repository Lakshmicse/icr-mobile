import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/chips.dart';
import '../../core/widgets/search_field.dart';
import 'rfq_format.dart';
import 'rfq_links.dart';
import 'rfq_models.dart';
import 'rfq_navigation.dart';
import 'rfq_repository.dart';
import 'rfq_scope.dart';
import 'rfq_styles.dart';
import 'supplier_controllers.dart';
import 'widgets/board_parts.dart';
import 'widgets/rfq_widgets.dart';
import 'widgets/supplier_parts.dart';

/// "Find work": the supplier's open board of requirements (`GET /rfq/open`),
/// with the requirements they were invited to (`GET /rfq/invited`). Tabs
/// (Recommended, All open, Invited), search, sort, "Closing soon", "Verified
/// buyers" and Filters (city, budget); a card opens the requirement the way a
/// supplier reads it, where the bid is made.
class OpenRequirementsScreen extends StatefulWidget {
  const OpenRequirementsScreen({
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
  State<OpenRequirementsScreen> createState() => _OpenRequirementsScreenState();
}

class _OpenRequirementsScreenState extends State<OpenRequirementsScreen> {
  late final RfqHooks _hooks;
  late final SupplierBoardController _board;
  final _search = TextEditingController();
  final _scroll = ScrollController();

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
    _board = SupplierBoardController(_hooks.repository)..start();
    // The service names on the cards come from the taxonomy; the board reads
    // fine without them (the key in words) until it arrives.
    unawaited(_hooks.repository.categories().then((_) => mounted ? setState(() {}) : null, onError: (_) => null));
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _board.loadMore();
    });
  }

  @override
  void dispose() {
    _board.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _name(String key) => _hooks.repository.categoryName(key) ?? prettyKey(key);

  Future<void> _open(Requirement r) async {
    await pushOpportunity(context, _hooks, r.id);
    if (mounted) await _board.refresh();
  }

  Future<void> _pickSort() async {
    final picked = await pickOne<BoardSort>(
      context,
      title: 'Sort by',
      options: BoardSort.values,
      labelOf: (s) => s.label,
      selected: _board.query.sort,
    );
    if (picked?.value != null) await _board.setSort(picked!.value!);
  }

  Future<void> _filters() async {
    final values = await showBoardFilters(context, _board.query);
    if (values == null) return;
    await _board.setFilters(city: values.city, minBudget: values.minBudget, maxBudget: values.maxBudget);
  }

  Future<void> _startSelling() async {
    final message = await _board.startSellingAndReload();
    if (message != null && mounted) showMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _board,
      builder: (context, _) => RfqScaffold(
        title: 'Find work',
        onBack: widget.onBack ?? () => Navigator.maybePop(context),
        unread: _board.unread,
        onBell: widget.onBell ?? () => pushAlerts(context, _hooks),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _board.refresh,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: _slivers(),
          ),
        ),
      ),
    );
  }

  List<Widget> _slivers() {
    final b = _board;
    Widget fill(Widget child) => SliverFillRemaining(hasScrollBody: false, child: child);
    final gate = b.gate;
    if (gate != null) {
      return [fill(SupplierGateView(gate: gate, what: 'find work', onStartSelling: _startSelling))];
    }
    if (b.loading && b.rows.isEmpty && b.access == null) return [fill(const RfqSpinner())];
    if (b.error != null && b.rows.isEmpty) {
      return [
        fill(
          RfqNotice(
            icon: LucideIcons.cloudOff,
            title: "Couldn't load the board",
            body: b.error,
            action: 'Try again',
            onAction: b.refresh,
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(child: _toolbar()),
      if (b.loading && b.rows.isEmpty)
        fill(const RfqSpinner())
      else if (b.rows.isEmpty)
        fill(_empty())
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverList.separated(
            itemCount: b.rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = b.rows[i];
              return OpportunityCard(key: ValueKey('board-${r.id}'), rfq: r, nameOf: _name, onOpen: () => _open(r));
            },
          ),
        ),
      if (b.rows.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: b.loadingMore ? const RfqSpinner(size: 20) : const SizedBox(height: 20),
          ),
        ),
    ];
  }

  Widget _toolbar() {
    final b = _board;
    final q = b.query;
    final access = b.access;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IcrSearchField(controller: _search, hint: 'Search requirements, services, cities...', onSubmitted: b.setSearch),
        ),
        const SizedBox(height: 10),
        ChipRow(
          padding: 16,
          gap: 6,
          children: [
            IcrChip(
              key: const ValueKey('board-mybids'),
              label: 'My Bids',
              tone: ChipTone.outlined,
              icon: LucideIcons.send,
              trailing: b.myBidCount == 0 ? null : CountBadge(b.myBidCount, size: 16),
              onTap: () async {
                await pushMyBids(context, _hooks);
                if (mounted) await b.refresh();
              },
            ),
            IcrChip(
              key: const ValueKey('board-sort'),
              label: 'Sort: ${q.sort.label}',
              tone: ChipTone.outlined,
              trailing: const Icon(LucideIcons.chevronDown, size: 12, color: AppColors.onSurface),
              onTap: _pickSort,
            ),
            IcrChip(
              key: const ValueKey('board-closing'),
              label: 'Closing soon',
              tone: q.closingInDays == null ? ChipTone.outlined : ChipTone.primary,
              icon: LucideIcons.clock,
              onTap: b.toggleClosingSoon,
            ),
            IcrChip(
              key: const ValueKey('board-verified'),
              label: 'Verified buyers',
              tone: q.verifiedBuyer ? ChipTone.primary : ChipTone.outlined,
              icon: LucideIcons.badgeCheck,
              onTap: b.toggleVerifiedBuyers,
            ),
            IcrChip(
              key: const ValueKey('board-filters'),
              label: q.filterCount == 0 ? 'Filters' : 'Filters (${q.filterCount})',
              tone: q.filterCount == 0 ? ChipTone.outlined : ChipTone.primary,
              icon: LucideIcons.slidersHorizontal,
              onTap: _filters,
            ),
          ],
        ),
        const SizedBox(height: 12),
        PillTabs<BoardTab>(
          values: BoardTab.values,
          selected: b.tab,
          labelOf: (t) => t.label,
          countOf: (t) => t == BoardTab.invited && b.invitedOpen > 0 ? b.invitedOpen : null,
          onSelect: b.setTab,
        ),
        if (access != null && !access.verified)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: const RfqBanner(
              'Your supplier listing is not verified yet. You can read requirements, but you can bid only once it is.',
              tone: Tone.amber,
              icon: LucideIcons.shieldAlert,
            ),
          ),
        if (access != null && access.verified && access.bidLimit != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text('${access.bidsUsed} of ${access.bidLimit} quotes used this month', style: RfqText.small),
          ),
      ],
    );
  }

  Widget _empty() {
    final b = _board;
    final narrowed = b.query.search.isNotEmpty || b.query.filterCount > 0;
    if (b.tab == BoardTab.invited) {
      return const RfqNotice(
        icon: LucideIcons.mailOpen,
        title: 'No invitations',
        body: 'When a buyer invites you to quote on a requirement, it shows here.',
      );
    }
    if (narrowed) {
      return RfqNotice(
        icon: LucideIcons.searchX,
        title: 'No requirements match',
        body: 'Try other words, or take a filter off.',
        action: 'Clear search and filters',
        onAction: () {
          _search.clear();
          b.setSearch('');
          b.clearFilters();
        },
      );
    }
    if (b.tab == BoardTab.recommended) {
      return RfqNotice(
        icon: LucideIcons.sparkles,
        title: 'Nothing matched to your services yet',
        body: 'Recommended shows requirements in the categories you serve. See everything that is open.',
        action: 'See all open',
        onAction: () => b.setTab(BoardTab.open),
      );
    }
    return const RfqNotice(
      icon: LucideIcons.clipboardList,
      title: 'No open requirements right now',
      body: 'New requirements show here as buyers post them. Pull down to check again.',
    );
  }
}
