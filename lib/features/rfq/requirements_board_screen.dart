import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/search_field.dart';
import 'requirements_board_controller.dart';
import 'rfq_format.dart';
import 'rfq_links.dart';
import 'rfq_models.dart';
import 'rfq_navigation.dart';
import 'rfq_repository.dart';
import 'rfq_scope.dart';
import 'rfq_styles.dart';
import 'widgets/board_parts.dart';
import 'widgets/rfq_widgets.dart';

/// "Requirements": everything posted on ICR, the website's `/rfq` page (owner, 3 Nov 2026: "whatever is posted needs
/// to be seen"). The same list for every member, newest first, with a tab per status, search and paging. A card the
/// reader runs opens on the owner's page; any other opens the page suppliers read, which shows a reader who does not
/// sell the brief and says so. The member's own list, the composer and the supplier board are a chip away.
class RequirementsBoardScreen extends StatefulWidget {
  const RequirementsBoardScreen({
    super.key,
    this.repository,
    this.links,
    this.onBack,
    this.onBell,
    this.onOpenConversation,
    this.onOpenSupplier,
    this.onCreateCompany,
  });

  final RfqRepository? repository;
  final RfqLinks? links;
  final VoidCallback? onBack;

  /// The bell; by default it opens the requirement alerts.
  final VoidCallback? onBell;
  final ValueChanged<String>? onOpenConversation;
  final ValueChanged<String>? onOpenSupplier;
  final VoidCallback? onCreateCompany;

  @override
  State<RequirementsBoardScreen> createState() => _RequirementsBoardScreenState();
}

class _RequirementsBoardScreenState extends State<RequirementsBoardScreen> {
  late final RfqHooks _hooks;
  late final RequirementsBoardController _board;
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
      onCreateCompany: widget.onCreateCompany,
    );
    _board = RequirementsBoardController(_hooks.repository)..start();
    // The service names on the cards come from the taxonomy; the cards read fine without them until it arrives.
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
    if (_board.manages(r)) {
      await pushRfqDetail(context, _hooks, r.id);
    } else {
      await pushOpportunity(context, _hooks, r.id);
    }
    if (mounted) await _board.refresh();
  }

  Future<void> _after(Future<void> route) async {
    await route;
    if (mounted) await _board.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _board,
      builder: (context, _) => RfqScaffold(
        title: 'Requirements',
        onBack: widget.onBack ?? () => Navigator.maybePop(context),
        unread: _board.unread,
        onBell: widget.onBell ?? () => pushAlerts(context, _hooks),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _board.refresh,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _toolbar()),
              ..._body(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    final b = _board;
    final mine = b.mine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IcrSearchField(controller: _search, hint: 'Search Requirements', onSubmitted: b.setSearch),
        ),
        const SizedBox(height: 10),
        ChipRow(
          padding: 16,
          gap: 6,
          children: [
            if (b.offersPost)
              IcrChip(
                key: const ValueKey('posted-post'),
                label: 'Post RFQ',
                tone: ChipTone.outlined,
                icon: LucideIcons.circlePlus,
                onTap: () => _after(pushComposer(context, _hooks).then((_) {})),
              ),
            if (b.offersMine)
              IcrChip(
                key: const ValueKey('posted-mine'),
                label: "My RFQ's",
                tone: ChipTone.outlined,
                icon: LucideIcons.filePlus2,
                trailing: mine == null || mine == 0 ? null : CountBadge(mine, size: 16),
                onTap: () => _after(pushMyRfqs(context, _hooks)),
              ),
            if (b.offersFindWork)
              IcrChip(
                key: const ValueKey('posted-find-work'),
                label: 'Find Work',
                tone: ChipTone.outlined,
                icon: LucideIcons.compass,
                onTap: () => _after(pushBoard(context, _hooks)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        PillTabs<PostedTab>(
          values: PostedTab.values,
          selected: b.tab,
          labelOf: (t) => t.label,
          countOf: (_) => null,
          onSelect: b.setTab,
        ),
        if (b.rows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(key: const ValueKey('posted-total'), _totalLine(b), style: RfqText.small),
          ),
      ],
    );
  }

  String _totalLine(RequirementsBoardController b) {
    final n = b.total;
    final what = n == 1 ? 'requirement' : 'requirements';
    return switch (b.tab) {
      PostedTab.all => '$n $what posted',
      PostedTab.open => '$n open $what',
      PostedTab.awarded => '$n awarded',
      PostedTab.closed => '$n closed',
    };
  }

  List<Widget> _body() {
    final b = _board;
    Widget fill(Widget child) => SliverFillRemaining(hasScrollBody: false, child: child);
    if (b.loading && b.rows.isEmpty) return [fill(const RfqSpinner())];
    if (b.error != null && b.rows.isEmpty) {
      return [
        fill(
          RfqNotice(
            icon: LucideIcons.cloudOff,
            title: 'Unable to Load the Requirements',
            body: b.error,
            action: 'Try Again',
            onAction: b.refresh,
          ),
        ),
      ];
    }
    if (b.rows.isEmpty) return [fill(_empty())];
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        sliver: SliverList.separated(
          itemCount: b.rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final r = b.rows[i];
            return OpportunityCard(
              key: ValueKey('posted-${r.id}'),
              rfq: r,
              nameOf: _name,
              showStatus: true,
              onOpen: () => _open(r),
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: b.loadingMore
              ? const RfqSpinner(size: 20)
              : b.cutShort
              // The API reads only its first page (see the controller's pageSize): said, never left to look complete.
              ? Padding(
                  key: const ValueKey('posted-cut-short'),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Showing the newest ${b.rows.length} of ${b.total}. Search or select a tab to find the others.',
                    textAlign: TextAlign.center,
                    style: RfqText.small,
                  ),
                )
              : const SizedBox(height: 20),
        ),
      ),
    ];
  }

  Widget _empty() {
    final b = _board;
    if (b.narrowed) {
      return RfqNotice(
        icon: LucideIcons.searchX,
        title: 'No Requirements Match',
        body: 'Try different words.',
        action: 'Clear Search',
        onAction: () {
          _search.clear();
          b.setSearch('');
        },
      );
    }
    if (b.tab != PostedTab.all) {
      return RfqNotice(
        icon: LucideIcons.clipboardList,
        title: 'None ${b.tab.label} Right Now',
        body: 'Everything posted is under All.',
        action: 'See All',
        onAction: () => b.setTab(PostedTab.all),
      );
    }
    return RfqNotice(
      icon: LucideIcons.clipboardList,
      title: 'No Requirements Posted Yet',
      body: 'Requirements will appear here as buyers post them. Pull down to refresh.',
      action: b.offersPost ? 'Post Requirement' : null,
      onAction: b.offersPost ? () => _after(pushComposer(context, _hooks).then((_) {})) : null,
    );
  }
}
