import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/util/links.dart' show showMessage;
import '../shell/app_shell.dart';
import 'community_manage_controllers.dart';
import 'community_manage_kit.dart';
import 'community_manage_models.dart';
import 'community_manage_repository.dart';
import 'content_sheets.dart';
import 'manage_council_screen.dart';
import 'org_list_parts.dart';
import 'org_sheets.dart';

/// Manage Councils — the website's `/admin/community` for staff holding `councils:manage` (Councils Admin,
/// Community Manager, Super Admin): the **Councils** tab is every council, unpublished included, searched by name
/// or focus and paged by twenty, each row opening the council's manage page; **Proposals** is members proposing a
/// new council, approved (a note optional) or declined (the reason required). "New Council" is drawn only when the
/// key is held [everywhere].
class ManageCouncilsScreen extends StatefulWidget {
  const ManageCouncilsScreen({
    super.key,
    required this.repository,
    required this.everywhere,
    required this.onBack,
    this.onBell,
    this.unread = 0,
    this.initialSearch,
    this.initialTab,
    this.focusProposalId,
    this.pageWrap,
    this.pickers = const ManagePickers(),
    this.searchDelay = const Duration(milliseconds: 350),
  });

  final CommunityManageRepository repository;
  final bool everywhere;
  final VoidCallback onBack;
  final VoidCallback? onBell;
  final int unread;

  /// Prefills the list's search (the website's `?search=`).
  final String? initialSearch;

  /// `'proposals'` (or the website's `'applications'`) opens on the Proposals tab.
  final String? initialTab;

  /// A proposal a notification named (`?proposal=<id>`): tinted and scrolled to.
  final String? focusProposalId;

  /// Puts each page this screen pushes into the app's frame (the bottom bar under it).
  final Widget Function(Widget page)? pageWrap;
  final ManagePickers pickers;
  final Duration searchDelay;

  @override
  State<ManageCouncilsScreen> createState() => _ManageCouncilsScreenState();
}

class _ManageCouncilsScreenState extends State<ManageCouncilsScreen> {
  late final _searchText = TextEditingController(text: widget.initialSearch ?? '');
  late final OrgListController<AdminCouncil> _list = OrgListController<AdminCouncil>(
    fetch: (page, search) => widget.repository.councils(page: page, search: search),
    initialSearch: widget.initialSearch ?? '',
    searchDelay: widget.searchDelay,
  );
  late final RequestsController<CouncilProposal> _requests = RequestsController<CouncilProposal>(
    fetch: (status, page) => widget.repository.councilProposals(status: status, page: page),
    decide: (id, decision, reason) =>
        widget.repository.decide(OrgKind.council, id, decision: decision, reason: reason),
  );
  late int _tab =
      widget.initialTab == 'proposals' || widget.initialTab == 'applications' || widget.focusProposalId != null
      ? 1
      : 0;

  @override
  void initState() {
    super.initState();
    _list.start();
    if (_tab == 1) _requests.start();
  }

  @override
  void dispose() {
    _searchText.dispose();
    _list.dispose();
    _requests.dispose();
    super.dispose();
  }

  void _showTab(int tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    if (tab == 1 && !_requests.started) _requests.start(announce: true);
  }

  Future<void> _new() async {
    final created = await showCouncilSheet(
      context,
      repository: widget.repository,
      pickers: widget.pickers,
      onSubmit: (draft) async {
        try {
          await widget.repository.createCouncil(draft.body());
          return null;
        } catch (e) {
          return ApiError.from(e).message;
        }
      },
    );
    if (!created || !mounted) return;
    showMessage(context, 'Council created.');
    await _list.refresh();
  }

  Future<void> _open(AdminCouncil council) async {
    final wrap = widget.pageWrap ?? (Widget page) => page;
    await AppShell.push<void>(
      context,
      (page) => wrap(
        ManageCouncilScreen(
          repository: widget.repository,
          councilId: council.id,
          initial: council,
          everywhere: widget.everywhere,
          onBack: () => Navigator.of(page).maybePop(),
          onBell: widget.onBell,
          unread: widget.unread,
          pageWrap: widget.pageWrap,
          pickers: widget.pickers,
        ),
      ),
    );
    // Whatever was edited or retired there shows here.
    if (mounted) await _list.refresh();
  }

  Future<void> _decide(RequestView request, {required bool declining}) async {
    final decided = await showDecideSheet(
      context,
      kind: OrgKind.council,
      title: request.title,
      declining: declining,
      onSubmit: (reason) => _requests.decide(
        request.id,
        decision: declining ? RequestStatus.declined : RequestStatus.approved,
        reason: reason,
      ),
    );
    if (!decided || !mounted) return;
    showMessage(context, declining ? 'Proposal declined.' : 'Proposal approved.');
    // An approval sets up the council, unpublished.
    if (!declining) await _list.refresh();
  }

  /// An approval's "Find It": the Councils tab, searched by the council's name.
  void _find(String name) {
    _searchText.text = name;
    setState(() => _tab = 0);
    _list.searchNow(name);
  }

  @override
  Widget build(BuildContext context) {
    return ManageFrame(
      title: 'Manage Councils',
      onBack: widget.onBack,
      onBell: widget.onBell,
      unread: widget.unread,
      tabs: const ['Councils', 'Proposals'],
      tab: _tab,
      onTab: _showTab,
      child: _tab == 0
          ? OrgListTab<AdminCouncil>(
              key: const ValueKey('councils-tab'),
              controller: _list,
              searchText: _searchText,
              searchHint: 'Search councils by name or focus',
              emptyTitle: 'No Councils',
              newLabel: widget.everywhere ? 'New Council' : null,
              onNew: widget.everywhere ? _new : null,
              rowBuilder: (c) => OrgRow(
                key: ValueKey('council-row-${c.id}'),
                title: c.name,
                subtitle: c.segments.join(' · '),
                meta: '${c.memberCount} ${c.memberCount == 1 ? 'member' : 'members'}',
                published: c.published,
                onTap: () => _open(c),
              ),
            )
          : RequestsTab<CouncilProposal>(
              key: const ValueKey('proposals-tab'),
              controller: _requests,
              viewOf: RequestView.ofProposal,
              emptyTitle: 'No Council Proposals',
              focusId: widget.focusProposalId,
              onDecide: _decide,
              onFind: _find,
            ),
    );
  }
}
