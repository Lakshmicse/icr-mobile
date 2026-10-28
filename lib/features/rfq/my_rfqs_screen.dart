import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show showMessage;
import '../../core/widgets/chips.dart';
import '../../core/widgets/search_field.dart';
import 'my_rfqs_controller.dart';
import 'rfq_format.dart';
import 'rfq_links.dart';
import 'rfq_models.dart';
import 'rfq_navigation.dart';
import 'rfq_repository.dart';
import 'rfq_scope.dart';
import 'rfq_styles.dart';
import 'widgets/requirement_parts.dart';
import 'widgets/rfq_widgets.dart';

/// "My RFQ's": the buyer's requirements, with their counts, what is waiting
/// on the buyer, and each requirement's next step (`/manage/requirements` on
/// the website).
class MyRfqsScreen extends StatefulWidget {
  const MyRfqsScreen({
    super.key,
    this.repository,
    this.links,
    this.onBack,
    this.onBell,
    this.onOpenConversation,
    this.onOpenSupplier,
    this.onCreateCompany,
  });

  /// The data source; by default the one [rfqRepositoryOf] finds.
  final RfqRepository? repository;
  final RfqLinks? links;

  /// The arrow at the top left; by default it pops the route.
  final VoidCallback? onBack;

  /// The bell; by default it opens the requirement alerts.
  final VoidCallback? onBell;
  final ValueChanged<String>? onOpenConversation;
  final ValueChanged<String>? onOpenSupplier;

  /// Founds a company, for an account that has none (the gate this list shows it): the account screens'.
  final VoidCallback? onCreateCompany;

  @override
  State<MyRfqsScreen> createState() => _MyRfqsScreenState();
}

class _MyRfqsScreenState extends State<MyRfqsScreen> {
  late final RfqHooks _hooks;
  late final MyRfqsController _rfqs;
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _hooks = RfqHooks(
      repository: widget.repository ?? rfqRepositoryOf(context),
      links: widget.links ?? const SystemRfqLinks(),
      onOpenConversation: widget.onOpenConversation,
      onOpenSupplier: widget.onOpenSupplier,
      onCreateCompany: widget.onCreateCompany,
    );
    _rfqs = MyRfqsController(_hooks.repository)..start();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _rfqs.loadMore();
    });
  }

  @override
  void dispose() {
    _rfqs.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final result = await pushComposer(context, _hooks);
    if (result != null) await _rfqs.refresh();
  }

  Future<void> _open(Requirement r, {String? section}) async {
    await pushRfqDetail(context, _hooks, r.id, section: section);
    if (mounted) await _rfqs.refresh();
  }

  Future<void> _say(Future<String?> action) async {
    final message = await action;
    if (message != null && mounted) showMessage(context, message);
  }

  Future<void> _menu(Requirement r) async {
    final enquiry = r.isEnquiry;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuRow(icon: LucideIcons.eye, label: 'View', value: 'view'),
            if (r.status == RfqStatus.draft || r.status == RfqStatus.published)
              _MenuRow(icon: LucideIcons.pencil, label: 'Edit', value: 'edit'),
            if (r.status == RfqStatus.draft) _MenuRow(icon: LucideIcons.send, label: 'Publish', value: 'publish'),
            _MenuRow(icon: LucideIcons.copy, label: 'Post a similar requirement', value: 'similar'),
            if (r.status == RfqStatus.published || r.status == RfqStatus.awarded)
              _MenuRow(icon: LucideIcons.lock, label: enquiry ? 'Close enquiry' : 'Close requirement', value: 'close'),
            if (r.status == RfqStatus.published)
              _MenuRow(
                icon: LucideIcons.ban,
                label: enquiry ? 'Cancel enquiry' : 'Cancel requirement',
                value: 'cancel',
                danger: true,
              ),
            if (r.status == RfqStatus.draft)
              _MenuRow(icon: LucideIcons.trash2, label: 'Delete draft', value: 'delete', danger: true),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'view':
        await _open(r);
      case 'edit':
        final saved = await pushComposer(context, _hooks, editId: r.id);
        if (saved != null) await _rfqs.refresh();
      case 'similar':
        final posted = await pushComposer(context, _hooks, copyFromId: r.id);
        if (posted != null) await _rfqs.refresh();
      case 'publish':
        await _say(_rfqs.act(r, RfqAction.publish));
      case 'close':
        if (await confirmMove(
          context,
          title: 'Close this requirement?',
          body: 'Suppliers can no longer reply. The responses you have stay here.',
          confirm: 'Close it',
        )) {
          await _say(_rfqs.act(r, RfqAction.close));
        }
      case 'cancel':
        if (await confirmMove(
          context,
          title: 'Cancel this requirement?',
          body: 'It is taken off the board and suppliers can no longer reply. This can’t be undone.',
          confirm: 'Cancel requirement',
          destructive: true,
        )) {
          await _say(_rfqs.act(r, RfqAction.cancel));
        }
      case 'delete':
        if (await confirmMove(
          context,
          title: 'Delete this draft?',
          body: 'Only your team has seen it. It is deleted for good.',
          confirm: 'Delete draft',
          destructive: true,
        )) {
          await _say(_rfqs.deleteDraft(r));
        }
    }
  }

  Future<void> _pickKind() async {
    final picked = await pickOne<RfqKind>(
      context,
      title: 'Requirement type',
      options: RfqKind.values,
      labelOf: (k) => k == RfqKind.enquiry ? 'Enquiries' : 'RFQs',
      selected: _rfqs.kind,
      clearLabel: 'All types',
    );
    if (picked != null) await _rfqs.setKind(picked.value);
  }

  Future<void> _pickSort() async {
    final picked = await pickOne<MySort>(
      context,
      title: 'Sort by',
      options: MySort.values,
      labelOf: (s) => s.label,
      selected: _rfqs.sort,
    );
    if (picked?.value != null) await _rfqs.setSort(picked!.value!);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _rfqs,
      builder: (context, _) => RfqScaffold(
        title: "My RFQ's",
        onBack: widget.onBack ?? () => Navigator.maybePop(context),
        unread: _rfqs.unread,
        onBell: widget.onBell ?? () => pushAlerts(context, _hooks),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _rfqs.refresh,
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
    final rfqs = _rfqs;
    final kindLabel = switch (rfqs.kind) {
      null => 'All types',
      RfqKind.enquiry => 'Enquiries',
      RfqKind.rfq => 'RFQs',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IcrSearchField(controller: _search, hint: 'Search your requirements', onSubmitted: rfqs.setSearch),
        ),
        const SizedBox(height: 10),
        ChipRow(
          padding: 16,
          gap: 6,
          children: [
            IcrChip(
              key: const ValueKey('rfq-post'),
              label: 'Post RFQ',
              tone: ChipTone.outlined,
              icon: LucideIcons.circlePlus,
              onTap: _post,
            ),
            IcrChip(
              key: const ValueKey('rfq-kind'),
              label: kindLabel,
              tone: rfqs.kind == null ? ChipTone.outlined : ChipTone.primary,
              trailing: Icon(
                LucideIcons.chevronDown,
                size: 12,
                color: rfqs.kind == null ? AppColors.onSurface : Colors.white,
              ),
              onTap: _pickKind,
            ),
            IcrChip(
              key: const ValueKey('rfq-sort'),
              label: 'Sort: ${rfqs.sort.label}',
              tone: ChipTone.outlined,
              trailing: const Icon(LucideIcons.chevronDown, size: 12, color: AppColors.onSurface),
              onTap: _pickSort,
            ),
          ],
        ),
        const SizedBox(height: 12),
        PillTabs<MyView>(
          values: MyView.values,
          selected: rfqs.view,
          labelOf: (v) => v.label,
          countOf: (v) => rfqs.summary == null ? null : rfqs.count(v),
          onSelect: rfqs.setView,
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  List<Widget> _body() {
    final rfqs = _rfqs;
    Widget fill(Widget child) => SliverFillRemaining(hasScrollBody: false, child: child);
    if (rfqs.loading && rfqs.rows.isEmpty) return [fill(const RfqSpinner())];
    if (rfqs.forbidden && (rfqs.poster?.roleCannotPost ?? false)) {
      // A member of a company, in a role that does not run requirements: a new company page is not the fix.
      return [
        fill(
          RfqNotice(
            key: const ValueKey('role-cannot-post'),
            icon: LucideIcons.lock,
            title: "Requirements aren't part of your role",
            body: rfqs.poster!.cannotPostMessage,
          ),
        ),
      ];
    }
    if (rfqs.forbidden) {
      return [
        fill(
          RfqNotice(
            icon: LucideIcons.building2,
            title: 'Requirements are posted by buyers and companies',
            body:
                'Your account cannot post requirements yet. Create a company page to buy on ICR, or ask a company admin to add you as a buyer.',
            action: 'Create a company page',
            onAction: _hooks.onCreateCompany ?? () => _hooks.openSite(context, '/account/companies/new'),
          ),
        ),
      ];
    }
    if (rfqs.error != null && rfqs.rows.isEmpty) {
      return [
        fill(
          RfqNotice(
            icon: LucideIcons.cloudOff,
            title: "Couldn't load your requirements",
            body: rfqs.error,
            action: 'Try again',
            onAction: rfqs.refresh,
          ),
        ),
      ];
    }
    if (rfqs.nothingAtAll) {
      return [
        fill(
          RfqNotice(
            icon: LucideIcons.clipboardList,
            title: 'Post your first requirement',
            body: 'Describe what you need once; matched suppliers are alerted and their quotes come back here.',
            action: 'Post RFQ',
            onAction: _post,
          ),
        ),
      ];
    }
    final children = <Widget>[];
    final summary = rfqs.summary;
    if (summary != null && rfqs.view == MyView.all && summary.actionItems.isNotEmpty && !rfqs.narrowed) {
      children.add(_actionItems(summary));
    }
    if (rfqs.rows.isEmpty) {
      children.add(
        RfqNotice(
          icon: LucideIcons.searchX,
          title: rfqs.narrowed ? 'No requirements match' : 'Nothing in ${rfqs.view.label.toLowerCase()}',
          body: rfqs.narrowed
              ? 'Try other words, or show every type.'
              : 'Requirements show here as they reach this state.',
          action: rfqs.narrowed ? 'Clear search' : null,
          onAction: rfqs.narrowed
              ? () {
                  _search.clear();
                  rfqs.clearFilters();
                }
              : null,
        ),
      );
    }
    for (final r in rfqs.rows) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: RequirementCard(
            key: ValueKey('rfq-row-${r.id}'),
            rfq: r,
            nameOf: (k) => _hooks.repository.categoryName(k) ?? prettyKey(k),
            busy: rfqs.isBusy(r.id),
            onOpen: () => _open(r),
            onPrimary: () => _open(r, section: primaryOf(r).section),
            onMenu: () => _menu(r),
          ),
        ),
      );
    }
    children.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: rfqs.loadingMore ? const RfqSpinner(size: 20) : const SizedBox(height: 20),
      ),
    );
    return [SliverList(delegate: SliverChildListDelegate(children))];
  }

  Widget _actionItems(RequirementsSummary summary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: RfqCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.bellRing, size: 16, color: AppColors.amber800),
                const SizedBox(width: 8),
                Expanded(child: Text('Waiting on you', style: RfqText.section.copyWith(fontSize: 14))),
                Text('${summary.actionCount}', style: RfqText.metaStrong),
              ],
            ),
            const SizedBox(height: 4),
            for (final a in summary.actionItems)
              InkWell(
                key: ValueKey('rfq-action-${a.rfqId}'),
                onTap: () async {
                  await pushRfqDetail(context, _hooks, a.rfqId, section: a.kind == 'SCREEN' ? 'prequal' : null);
                  if (mounted) await _rfqs.refresh();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title, style: RfqText.metaStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(
                              actionSentence(a) + (a.deadline == null ? '' : ' · by ${shortDay(a.deadline!)}'),
                              style: RfqText.small,
                            ),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.slate400),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.value, this.danger = false});

  final IconData icon;
  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.slate900;
    return ListTile(
      leading: Icon(icon, size: 20, color: color),
      title: Text(
        label,
        style: RfqText.body.copyWith(color: color, fontWeight: FontWeight.w500),
      ),
      onTap: () => Navigator.pop(context, value),
    );
  }
}

/// One of the buyer's requirements on the list.
class RequirementCard extends StatelessWidget {
  const RequirementCard({
    super.key,
    required this.rfq,
    required this.nameOf,
    required this.onOpen,
    required this.onPrimary,
    required this.onMenu,
    this.busy = false,
    this.now,
  });

  final Requirement rfq;
  final CategoryNamer nameOf;
  final VoidCallback onOpen;
  final VoidCallback onPrimary;
  final VoidCallback onMenu;
  final bool busy;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final clock = now ?? RfqClock.now();
    final deadline = deadlineOf(rfq, clock);
    final responses = responsesOf(rfq);
    final primary = primaryOf(rfq);
    final places = rfq.places;
    return RfqCard(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    kicker(rfq, serviceLabelOf(rfq, nameOf)),
                    style: RfqText.kicker,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (busy)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  StatusPill(rfq.status),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(rfq.title, style: RfqText.cardTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              if (places.isNotEmpty)
                _Meta(
                  icon: LucideIcons.mapPin,
                  text: places.length > 2 ? '${places.take(2).join(', ')} +${places.length - 2}' : places.join(', '),
                ),
              if (deadline != null)
                _Meta(
                  icon: LucideIcons.clock,
                  text: '${deadline.label} ${deadline.relative}',
                  color: switch (deadline.urgency) {
                    Urgency.urgent => AppColors.error,
                    Urgency.soon => AppColors.amber800,
                    _ => null,
                  },
                ),
              if (rfq.visibility == RfqVisibility.targeted) const _Meta(icon: LucideIcons.lock, text: 'Invite only'),
              if (rfq.postedBy != null) _Meta(icon: LucideIcons.user, text: 'Posted by ${rfq.postedBy}'),
              if (rfq.awardedTo != null) _Meta(icon: LucideIcons.trophy, text: 'Awarded to ${rfq.awardedTo}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: '${responses.total} ${responses.noun}',
                    style: RfqText.metaStrong,
                    children: [
                      if (responses.fresh > 0)
                        TextSpan(
                          text: ' · ${responses.fresh} ${responses.freshNoun}',
                          style: RfqText.metaStrong.copyWith(color: AppColors.primary),
                        ),
                    ],
                  ),
                ),
              ),
              _SmallButton(
                label: primary.count == null ? primary.label : '${primary.label} (${primary.count})',
                filled: primary.count != null,
                onTap: onPrimary,
              ),
              IconButton(
                tooltip: 'More',
                visualDensity: VisualDensity.compact,
                onPressed: busy ? null : onMenu,
                icon: const Icon(LucideIcons.ellipsisVertical, size: 18, color: AppColors.slate600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color ?? AppColors.slate500),
        const SizedBox(width: 4),
        Text(text, style: RfqText.small.copyWith(color: color)),
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap, this.filled = false});

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: filled ? AppColors.primary : AppColors.slate200),
    );
    return Material(
      color: filled ? AppColors.primary : Colors.white,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: RfqText.tab.copyWith(fontSize: 12, color: filled ? Colors.white : AppColors.primary),
          ),
        ),
      ),
    );
  }
}
