import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart' show openExternal;
import '../../core/widgets/chips.dart';
import '../../core/widgets/title_bar.dart';
import '../chapters/community_kit.dart' show CommunitySearchField;
import '../notifications/notifications_screen.dart';
import '../workspaces/page_kit.dart';
import 'community_manage_controllers.dart';
import 'community_manage_kit.dart';
import 'community_manage_models.dart';
import 'community_manage_rules.dart';

/// The two tabs Manage Chapters and Manage Councils are made of: the staff list (search, a page of twenty, the
/// button that starts a new record) and members' requests (a state at a time, each with Approve and Decline).

/// The frame of Manage Chapters and Manage Councils: the title bar with the bell, the two tabs, and the open tab.
class ManageFrame extends StatelessWidget {
  const ManageFrame({
    super.key,
    required this.title,
    required this.onBack,
    required this.tabs,
    required this.tab,
    required this.onTab,
    required this.child,
    this.onBell,
    this.unread = 0,
  });

  final String title;
  final VoidCallback onBack;
  final List<String> tabs;
  final int tab;
  final ValueChanged<int> onTab;
  final Widget child;
  final VoidCallback? onBell;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitleBar(title: title, onBack: onBack, unread: unread, onBell: onBell ?? () => openNotifications(context)),
            ManageTabs(labels: tabs, selected: tab, onSelect: onTab),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// The list tab: the search and the New button over the rows, a hairline between each, the pager under them.
class OrgListTab<T> extends StatelessWidget {
  const OrgListTab({
    super.key,
    required this.controller,
    required this.searchText,
    required this.searchHint,
    required this.emptyTitle,
    required this.rowBuilder,
    this.newLabel,
    this.onNew,
  });

  final OrgListController<T> controller;
  final TextEditingController searchText;
  final String searchHint;
  final String emptyTitle;
  final Widget Function(T row) rowBuilder;

  /// "New Chapter"; left out for a role that reaches only some records, which the API lets create none.
  final String? newLabel;
  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => RefreshIndicator(
        color: AppColors.primary,
        onRefresh: c.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: CommunitySearchField(
                      key: const ValueKey('manage-search'),
                      controller: searchText,
                      onChanged: c.setSearch,
                      hint: searchHint,
                    ),
                  ),
                  if (newLabel != null && onNew != null) ...[
                    const SizedBox(width: 10),
                    WsButton(
                      key: const ValueKey('manage-new'),
                      label: newLabel!,
                      icon: LucideIcons.plus,
                      filled: true,
                      onPressed: onNew,
                    ),
                  ],
                ],
              ),
            ),
            const WsDivider(),
            if (c.loading && !c.loaded)
              const ManageState.loading(key: ValueKey('manage-list-loading'))
            else if (c.error != null && !c.loaded)
              ManageState.message(c.error!, key: const ValueKey('manage-list-error'), onRetry: c.refresh)
            else if (c.rows.isEmpty)
              ManageState.message(emptyTitle, key: const ValueKey('manage-list-empty'))
            else
              for (final row in c.rows) ...[rowBuilder(row), const WsDivider()],
            if (c.error != null && c.loaded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(c.error!, key: const ValueKey('manage-list-inline-error'), style: WsText.body),
              ),
            ManagePager(page: c.page, totalPages: c.totalPages, onPage: c.setPage),
          ],
        ),
      ),
    );
  }
}

/// One chapter or council in the staff list: its name, where it is or whom it serves, its size, and whether it is
/// listed. The whole row opens the record's manage page.
class OrgRow extends StatelessWidget {
  const OrgRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.published,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String meta;
  final bool published;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: WsText.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: WsText.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 2),
                  Text(meta, style: WsText.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 10),
            PublishPill(published: published),
            const SizedBox(width: 2),
            const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}

/// A member's request as its row draws it, whichever kind it is.
class RequestView {
  const RequestView({
    required this.id,
    required this.title,
    required this.status,
    this.kindLabel,
    this.person,
    this.metaLine = '',
    this.linkedinUrl,
    this.blocks = const [],
    this.chips = const [],
    this.reason,
    this.decidedAt,
    this.result,
  });

  factory RequestView.ofApplication(ChapterApplication a) => RequestView(
    id: a.id,
    title: a.title,
    status: a.status,
    kindLabel: applicationKindLabel(a.kind),
    person: a.applicant?.line,
    metaLine: [
      [a.city, a.country].where((v) => v.isNotEmpty).join(', '),
      if (a.createdAt != null) 'sent ${mediumDate(a.createdAt!)}',
    ].where((v) => v.isNotEmpty).join(' · '),
    linkedinUrl: a.linkedinUrl,
    blocks: [('Why, and What the Chapter Would Do', a.motivation), ('Experience', a.experience)],
    reason: a.decisionReason,
    decidedAt: a.decidedAt,
    result: a.result,
  );

  factory RequestView.ofProposal(CouncilProposal p) => RequestView(
    id: p.id,
    title: p.name,
    status: p.status,
    person: p.proposer?.line,
    metaLine: p.createdAt == null ? '' : 'sent ${mediumDate(p.createdAt!)}',
    blocks: [('Focus', p.focus), ('Objectives', p.objectives), ('Why ICR Needs It', p.motivation)],
    chips: p.segments,
    reason: p.decisionReason,
    decidedAt: p.decidedAt,
    result: p.result,
  );

  final String id;
  final String title;
  final String status;
  final String? kindLabel;
  final String? person;
  final String metaLine;
  final String? linkedinUrl;

  /// A label and the member's words under it.
  final List<(String, String)> blocks;
  final List<String> chips;
  final String? reason;
  final DateTime? decidedAt;
  final RequestResult? result;

  bool get pending => status == RequestStatus.pending;
}

/// The requests tab: the state filter ("To review" first), then each request in full — who sent it, what they
/// wrote, how it was decided — with Decline and Approve on the ones still waiting.
class RequestsTab<T> extends StatefulWidget {
  const RequestsTab({
    super.key,
    required this.controller,
    required this.viewOf,
    required this.emptyTitle,
    required this.onDecide,
    required this.onFind,
    this.focusId,
  });

  final RequestsController<T> controller;
  final RequestView Function(T row) viewOf;
  final String emptyTitle;

  /// Decline (`declining`) or approve one request.
  final void Function(RequestView request, {required bool declining}) onDecide;

  /// Shows an approval's result in the list tab, searched by its name.
  final ValueChanged<String> onFind;

  /// A request a notification named: tinted, and scrolled to once it is on the page.
  final String? focusId;

  @override
  State<RequestsTab<T>> createState() => _RequestsTabState<T>();
}

class _RequestsTabState<T> extends State<RequestsTab<T>> {
  final _focusKey = GlobalKey();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_maybeScroll);
    _maybeScroll();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_maybeScroll);
    super.dispose();
  }

  void _maybeScroll() {
    if (_scrolled || widget.focusId == null || !widget.controller.loaded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _focusKey.currentContext;
      if (_scrolled || !mounted || target == null) return;
      _scrolled = true;
      Scrollable.ensureVisible(target, alignment: 0.05, duration: const Duration(milliseconds: 250));
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => RefreshIndicator(
        color: AppColors.primary,
        onRefresh: c.refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    for (final (i, s) in RequestStatus.all.indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      IcrChip(
                        key: ValueKey('request-filter-$s'),
                        label: requestFilterLabel(s),
                        tone: s == c.status ? ChipTone.primary : ChipTone.filled,
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: WsText.bodyStrong.copyWith(
                          color: s == c.status ? Colors.white : AppColors.onSurfaceVariant,
                        ),
                        onTap: () => c.setStatus(s),
                      ),
                    ],
                  ],
                ),
              ),
              const WsDivider(),
              if (c.loading && !c.loaded)
                const ManageState.loading(key: ValueKey('requests-loading'))
              else if (c.error != null && !c.loaded)
                ManageState.message(c.error!, key: const ValueKey('requests-error'), onRetry: c.refresh)
              else if (c.rows.isEmpty)
                ManageState.message(widget.emptyTitle, key: const ValueKey('requests-empty'))
              else
                for (final row in c.rows.map(widget.viewOf)) ...[
                  _RequestRow(
                    key: row.id == widget.focusId ? _focusKey : ValueKey('request-${row.id}'),
                    request: row,
                    focused: row.id == widget.focusId,
                    onDecide: widget.onDecide,
                    onFind: widget.onFind,
                  ),
                  const WsDivider(),
                ],
              if (c.error != null && c.loaded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(c.error!, style: WsText.body),
                ),
              ManagePager(page: c.page, totalPages: c.totalPages, onPage: c.setPage),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    super.key,
    required this.request,
    required this.focused,
    required this.onDecide,
    required this.onFind,
  });

  final RequestView request;
  final bool focused;
  final void Function(RequestView request, {required bool declining}) onDecide;
  final ValueChanged<String> onFind;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final link = r.linkedinUrl == null ? null : Uri.tryParse(r.linkedinUrl!);
    final declined = r.status == RequestStatus.declined;
    return ColoredBox(
      color: focused ? WsColors.tint : Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(r.title, style: WsText.title)),
                if (r.kindLabel != null) ...[
                  const SizedBox(width: 8),
                  WsChip(r.kindLabel!),
                ],
              ],
            ),
            if ((r.person ?? '').isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(r.person!, style: WsText.body),
            ],
            if (r.metaLine.isNotEmpty || link != null)
              Row(
                children: [
                  Flexible(
                    child: Text(r.metaLine, style: WsText.meta, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  if (link != null) ...[
                    const SizedBox(width: 6),
                    WsLink(label: 'LinkedIn', onTap: () => openExternal(context, link)),
                  ],
                ],
              ),
            for (final (label, text) in r.blocks)
              if (text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(label, style: WsText.meta.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(text, style: WsText.body.copyWith(color: AppColors.onSurface)),
              ],
            if (r.chips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final s in r.chips) WsChip(s)]),
            ],
            if (!r.pending) ...[
              const SizedBox(height: 10),
              Text(
                [requestStatusLabel(r.status), if (r.decidedAt != null) mediumDate(r.decidedAt!)].join(' '),
                key: ValueKey('request-outcome-${r.id}'),
                style: WsText.meta,
              ),
              if ((r.reason ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                ManageNote(r.reason!, warn: declined),
              ],
              if (r.result != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Result: ${r.result!.name} '
                        '${r.result!.published ? '(published)' : '(unpublished — publish it from its tab when ready)'}',
                        style: WsText.body,
                      ),
                    ),
                    const SizedBox(width: 6),
                    WsLink(
                      key: ValueKey('request-find-${r.id}'),
                      label: 'Find It',
                      onTap: () => onFind(r.result!.name),
                    ),
                  ],
                ),
            ],
            if (r.pending) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  WsButton(
                    key: ValueKey('request-decline-${r.id}'),
                    label: 'Decline',
                    onPressed: () => onDecide(r, declining: true),
                  ),
                  const SizedBox(width: 8),
                  WsButton(
                    key: ValueKey('request-approve-${r.id}'),
                    label: 'Approve',
                    filled: true,
                    onPressed: () => onDecide(r, declining: false),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
