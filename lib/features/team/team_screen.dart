import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../account/widgets/account_kit.dart';
import '../account/widgets/account_session.dart';
import 'team_controller.dart';
import 'team_models.dart';
import 'team_repository.dart';
import 'team_rows.dart';
import 'team_rules.dart';
import 'team_sheets.dart';
import 'team_words.dart';

export 'team_rules.dart' show TeamTab, TeamViewer, teamTabOf;

/// The website's `/manage/team`: the company's people. Members (their role and office, edited or removed by the
/// admins who may), Requests (people who asked to join; the admin names the role and approves, or declines) and
/// Pending (people added from ICR who have not answered, and email invites still open), with "Add someone on ICR"
/// and "Invite by email" above them.
///
/// Only a company's team admins reach it (company admin, office admin, supplier account); anyone else is told it is
/// not theirs. `?tab=requests` (a "someone asked to join your team" notification) opens on Requests.
///
/// Left out of the app: the company inbox card, the inbox-topic and learning-role editors, and the seat history
/// (they are admin tuning, not the decisions a notification asks for).
class TeamScreen extends StatefulWidget {
  const TeamScreen({
    super.key,
    this.repository,
    this.initialTab = TeamTab.members,
    this.onBack,
    this.onOpenMember,
    this.searchDelay,
    this.onCreateCompany,
    this.viewer,
    this.inviteLearningRole,
  });

  /// Where the calls go; the API (or the sample team in demo mode) when null.
  final TeamRepository? repository;

  /// The tab to open on (`?tab=requests` opens Requests).
  final TeamTab initialTab;

  /// Back from the title bar; defaults to popping the route.
  final VoidCallback? onBack;

  /// A member's row opens their public profile when given.
  final void Function(String userId)? onOpenMember;

  /// How long typing settles before the add-person search or the invite's lookup runs.
  final Duration? searchDelay;

  /// "Create a company", offered to someone acting for no company. Hidden without it.
  final VoidCallback? onCreateCompany;

  /// Who is looking; read from the signed-in session when null.
  final TeamViewer? viewer;

  /// Opens on the invite form with this learning role ticked and the Member role chosen (`?invite=TRAINER`, the
  /// menu's "Add a trainer"); a plain invite form for someone who cannot give learning roles.
  final String? inviteLearningRole;

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late final TeamController _controller;
  late final TeamViewer _viewer;
  late TeamTab _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    final user = maybeAuth(context)?.user;
    _viewer = widget.viewer ?? (user == null ? const TeamViewer(id: '', role: '') : TeamViewer.of(user));
    _controller = TeamController(repository: widget.repository ?? teamRepositoryOf(context), viewer: _viewer)..load();
    final preset = widget.inviteLearningRole;
    if (preset != null && _viewer.reachesPage && _viewer.hasCompany) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _invite(learningRole: preset);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // --- what the buttons do -----------------------------------------------------------------------------------------

  Future<void> _approve(TeamRequest r) async {
    final done = await showApproveSheet(
      context,
      request: r,
      offices: _controller.data.offices,
      send: (role, branchId) => _controller.approve(r, role: role, branchId: branchId),
    );
    if (done && mounted) _say('${r.name} joined the team.');
  }

  Future<void> _decline(TeamRequest r) async {
    final ok = await confirmAction(
      context,
      title: TeamWords.declineTitle(r.name),
      message: TeamWords.declineBody,
      confirm: TeamWords.decline,
    );
    if (!ok || !mounted) return;
    if (await _controller.decline(r) && mounted) _say('Declined ${r.name}’s request.');
  }

  Future<void> _cancelAdd(PendingAdd a) async {
    if (await _controller.cancelAdd(a) && mounted) _say('Took back the add for ${a.name}.');
  }

  Future<void> _revoke(TeamInvite i) async {
    if (await _controller.revoke(i) && mounted) _say('Revoked the invite to ${i.email}.');
  }

  Future<void> _edit(TeamMember m) async {
    final saved = await showEditMemberSheet(
      context,
      member: m,
      viewer: _viewer,
      offices: _controller.data.offices,
      send: (patch) => _controller.update(m, patch),
    );
    if (saved && mounted) _say('Saved ${m.name}.');
  }

  Future<void> _remove(TeamMember m) async {
    final ok = await confirmAction(
      context,
      title: TeamWords.removeTitle(m.name),
      message: TeamWords.removeBody,
      confirm: TeamWords.remove,
    );
    if (!ok || !mounted) return;
    if (await _controller.remove(m) && mounted) _say('Removed ${m.name} from the team.');
  }

  Future<void> _addPerson() async {
    final asked = await showAddPersonSheet(
      context,
      viewer: _viewer,
      offices: _controller.data.offices,
      search: (q) => _controller.repository.findPeople(q),
      send: (person, role, branchId, learningRoles) =>
          _controller.addPerson(person, role: role, branchId: branchId, learningRoles: learningRoles),
      searchDelay: widget.searchDelay ?? const Duration(milliseconds: 300),
    );
    if (asked && mounted) {
      setState(() => _tab = TeamTab.pending);
      _say('Asked. They join once they accept.');
    }
  }

  Future<void> _invite({String? learningRole}) async {
    final preset = learningRole != null && _viewer.givesLearningRoles;
    final sent = await showInviteSheet(
      context,
      viewer: _viewer,
      offices: _controller.data.offices,
      initialRole: preset ? 'PROFESSIONAL' : null,
      initialLearningRoles: preset ? [learningRole] : const [],
      lookup: (email) => _controller.repository.lookup(email),
      sendInvite: (email, role, branchId, learningRoles) =>
          _controller.inviteByEmail(email: email, role: role, branchId: branchId, learningRoles: learningRoles),
      sendAdd: (person, role, branchId, learningRoles) =>
          _controller.addPerson(person, role: role, branchId: branchId, learningRoles: learningRoles),
      searchDelay: widget.searchDelay ?? const Duration(milliseconds: 400),
    );
    if (sent && mounted) {
      setState(() => _tab = TeamTab.pending);
      _say('Invite sent.');
    }
  }

  // --- the page ----------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainer,
      appBar: AccountBar(title: TeamWords.title, onBack: widget.onBack),
      body: _body(),
    );
  }

  Widget _body() {
    if (!_viewer.hasCompany) {
      return _Note(
        key: const Key('team.noCompany'),
        icon: Symbols.business,
        title: TeamWords.title,
        text: TeamWords.noCompanyLead,
        action: widget.onCreateCompany == null
            ? null
            : AccountButton(
                key: const Key('team.createCompany'),
                label: 'Create a company',
                icon: Symbols.add_business,
                expand: false,
                onPressed: widget.onCreateCompany,
              ),
      );
    }
    if (!_viewer.reachesPage) {
      return const _Note(
        key: Key('team.noAccess'),
        icon: Symbols.lock,
        title: TeamWords.noAccessTitle,
        text: TeamWords.noAccessBody,
      );
    }
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        if (c.loading && !c.loaded) return const AccountLoading();
        if (!c.loaded) {
          return AccountError(
            message: c.loadError ?? TeamWords.couldNotLoad,
            onRetry: c.load,
            title: TeamWords.couldNotLoad,
          );
        }
        return RefreshIndicator(onRefresh: () => c.load(refresh: true), child: _list(c));
      },
    );
  }

  Widget _list(TeamController c) {
    return ListView(
      key: const Key('team.list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        if (c.actionError != null) _ErrorBanner(message: c.actionError!, onClose: c.dismissError),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            _viewer.isSupplier ? TeamWords.subtitleSupplier : TeamWords.subtitleHiring,
            style: AccountText.body,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: AccountButton(
                  key: const Key('team.add'),
                  label: TeamWords.addSomeone,
                  height: 40,
                  onPressed: c.busy ? null : _addPerson,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AccountButton(
                  key: const Key('team.invite'),
                  label: TeamWords.inviteByEmail,
                  outlined: true,
                  height: 40,
                  onPressed: c.busy ? null : _invite,
                ),
              ),
            ],
          ),
        ),
        TeamTabs(
          selected: _tab,
          counts: {
            TeamTab.members: c.data.members.length,
            TeamTab.requests: c.data.requests.length,
            TeamTab.pending: c.pendingCount,
          },
          onSelect: (t) => setState(() => _tab = t),
        ),
        ...switch (_tab) {
          TeamTab.members => _members(c),
          TeamTab.requests => _requests(c),
          TeamTab.pending => _pending(c),
        },
      ],
    );
  }

  List<Widget> _members(TeamController c) {
    final members = c.data.members;
    if (members.isEmpty) {
      return [
        TeamSection(
          children: [
            TeamEmpty(
              key: const Key('team.members.empty'),
              title: TeamWords.noMembersTitle,
              text: _viewer.isSupplier ? TeamWords.emptySupplier : TeamWords.emptyHiring,
            ),
          ],
        ),
      ];
    }
    return [
      TeamSection(
        key: const Key('team.members'),
        children: [
          for (final (i, m) in members.indexed)
            MemberRow(
              member: m,
              first: i == 0,
              canEdit: _viewer.canEdit(m),
              canRemove: _viewer.actsOn(m),
              removing: c.busyKey == 'remove:${m.id}',
              disabled: c.busy,
              onEdit: () => _edit(m),
              onRemove: () => _remove(m),
              onOpen: widget.onOpenMember == null ? null : () => widget.onOpenMember!(m.id),
            ),
        ],
      ),
    ];
  }

  List<Widget> _requests(TeamController c) {
    final requests = c.data.requests;
    if (requests.isEmpty) {
      return [
        TeamSection(
          children: [
            TeamEmpty(key: const Key('team.requests.empty'), text: TeamWords.noRequests, icon: Symbols.how_to_reg),
          ],
        ),
      ];
    }
    return [
      TeamSection(
        key: const Key('team.requests'),
        title: TeamWords.askedToJoin(requests.length),
        children: [
          for (final (i, r) in requests.indexed)
            RequestRow(
              request: r,
              first: i == 0,
              approving: c.busyKey == 'approve:${r.userId}',
              declining: c.busyKey == 'decline:${r.userId}',
              disabled: c.busy,
              onApprove: () => _approve(r),
              onDecline: () => _decline(r),
              onOpen: widget.onOpenMember == null ? null : () => widget.onOpenMember!(r.userId),
            ),
        ],
      ),
    ];
  }

  List<Widget> _pending(TeamController c) {
    final adds = c.data.adds;
    final invites = c.data.invites;
    if (adds.isEmpty && invites.isEmpty) {
      return [
        TeamSection(
          children: [
            TeamEmpty(
              key: const Key('team.pending.empty'),
              text: TeamWords.nothingPending,
              icon: Symbols.hourglass_empty,
            ),
          ],
        ),
      ];
    }
    return [
      if (adds.isNotEmpty)
        TeamSection(
          key: const Key('team.adds'),
          title: TeamWords.waitingToAccept(adds.length),
          children: [
            for (final (i, a) in adds.indexed)
              PendingAddRow(
                add: a,
                first: i == 0,
                canCancel: _viewer.manages(a.role),
                cancelling: c.busyKey == 'cancel:${a.userId}',
                disabled: c.busy,
                onCancel: () => _cancelAdd(a),
              ),
          ],
        ),
      if (invites.isNotEmpty)
        TeamSection(
          key: const Key('team.invites'),
          title: TeamWords.pendingInvites(invites.length),
          children: [
            for (final (i, inv) in invites.indexed)
              InviteRow(
                invite: inv,
                first: i == 0,
                canRevoke: _viewer.manages(inv.role),
                revoking: c.busyKey == 'revoke:${inv.id}',
                disabled: c.busy,
                onRevoke: () => _revoke(inv),
              ),
          ],
        ),
    ];
  }
}

/// A calm full-page note: the page has no company to show, or is not this person's.
class _Note extends StatelessWidget {
  const _Note({super.key, required this.icon, required this.title, required this.text, this.action});

  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        AccountCard(
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, size: 26, color: AppColors.slate500),
              ),
              const SizedBox(height: 12),
              Text(title, style: AccountText.cardTitle, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(text, style: AccountText.body, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('team.error'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(message, style: AccountText.error.copyWith(fontSize: 14)),
            ),
          ),
          IconButton(
            key: const Key('team.error.close'),
            tooltip: 'Dismiss',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.slate500),
          ),
        ],
      ),
    );
  }
}
