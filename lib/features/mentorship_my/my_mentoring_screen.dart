import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/workspace_embed.dart';
import '../workspaces/page_kit.dart' show WsColors;
import 'mentoring_links.dart';
import 'mentoring_overview.dart';
import 'mentoring_repository.dart';
import 'my_mentoring_controller.dart';
import 'group_sessions_screen.dart';
import 'pairing_screen.dart';
import 'programmes_screen.dart';
import 'my_mentoring_tabs.dart';
import 'purchases_tab.dart';
import 'widgets/kit.dart';

/// Pushes "My mentoring" (the website's `/mentorship/my`), optionally on one tab.
Future<void> openMyMentoring(
  BuildContext context, {
  MyTab tab = MyTab.mentoring,
  MentorshipLinks? links,
  VoidCallback? onBack,
  OpenConversation? onOpenConversation,
  void Function(BuildContext context, String mentorProfileId)? onOpenMentor,
  void Function(BuildContext context)? onBell,
  OpenSitePath? onOpenWebsite,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => MyMentoringScreen(
      initialTab: tab,
      onBack: onBack,
      links: MentorshipLinks.resolve(
        context,
        links,
        onOpenConversation: onOpenConversation,
        onOpenMentor: onOpenMentor,
        onBell: onBell,
        onOpenWebsite: onOpenWebsite,
      ),
    ),
  ),
);

/// My mentoring: the member's pairings, requests, calendar, purchases, goals,
/// saved mentors, certificates and reports, one tab each, on the real API.
///
/// The shell pushes it with [openMyMentoring], or builds it as a tab/page with
/// `MyMentoringScreen(onBack: ...)`. It reads the signed-in session from the
/// `ApiClient` in `Provider`, and [MentorshipLinks] from `Provider` or [links].
class MyMentoringScreen extends StatefulWidget {
  const MyMentoringScreen({
    super.key,
    this.initialTab = MyTab.mentoring,
    this.onBack,
    this.links,
    this.repository,
    this.onOpenConversation,
    this.onOpenMentor,
    this.onBell,
    this.onOpenWebsite,
  });

  final MyTab initialTab;
  final VoidCallback? onBack;
  final MentorshipLinks? links;

  /// Opens the messaging feature's chat for a conversation id ("Message" on a pairing, a purchase, a room).
  final OpenConversation? onOpenConversation;

  /// Opens a mentor's profile by mentor profile id.
  final void Function(BuildContext context, String mentorProfileId)? onOpenMentor;

  /// The bell.
  final void Function(BuildContext context)? onBell;

  /// Opens a page of the website (a path such as `/notifications`): payments and the like.
  final OpenSitePath? onOpenWebsite;

  /// A seam for tests; the API by default.
  final MentoringRepository? repository;

  @override
  State<MyMentoringScreen> createState() => _MyMentoringScreenState();
}

class _MyMentoringScreenState extends State<MyMentoringScreen> {
  late final MyMentoringController _c;
  late final MentorshipLinks _links;
  late MyTab _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    final repo = widget.repository ?? MentoringRepository(api: context.read<ApiClient>());
    _links = MentorshipLinks.resolve(
      context,
      widget.links,
      onOpenConversation: widget.onOpenConversation,
      onOpenMentor: widget.onOpenMentor,
      onBell: widget.onBell,
      onOpenWebsite: widget.onOpenWebsite,
    );
    _c = MyMentoringController(repo)..start();
    _c.ensureTab(_tab);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _select(MyTab tab) {
    setState(() => _tab = tab);
    _c.ensureTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final tabs = [
          for (final t in MyTab.values)
            if (_visible(t)) t,
        ];
        final badges = [
          for (final t in tabs)
            switch (t) {
              MyTab.requests => _c.isMentor ? _c.pendingReceived.length : _c.pendingSent.length,
              _ => 0,
            },
        ];
        final body = Column(
          children: [
            ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: SegmentTabs(
                  labels: [for (final t in tabs) t.label],
                  selected: tabs.indexOf(_tab).clamp(0, tabs.length - 1),
                  onSelect: (i) => _select(tabs[i]),
                  badges: badges,
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: WsColors.hairline),
            Expanded(child: _body()),
          ],
        );
        // In a workspace's tab the workspace's bar and tab name the page: no heading of its own.
        if (WorkspaceEmbed.of(context)) return Material(color: Colors.white, child: body);
        return MentoringPage(
          title: 'My Mentoring',
          onBack: widget.onBack,
          onBell: () => _links.notifications(context),
          body: body,
        );
      },
    );
  }

  /// The website's rules: saved mentors, purchases and goals are for someone who is
  /// a mentee; Reports show only once a concern was raised; Certificates once one was earned.
  /// The tab the member is on, or was sent to, always stays.
  bool _visible(MyTab t) {
    if (t == _tab) return true;
    return switch (t) {
      MyTab.saved || MyTab.purchases || MyTab.goals => _c.actsAsMentee,
      MyTab.reports => _c.concerns.data?.isNotEmpty ?? false,
      _ => true,
    };
  }

  Widget _body() {
    Future<void> refresh() => _c.refreshTab(_tab);
    switch (_tab) {
      case MyTab.mentoring:
        return MentoringOverview(controller: _c, links: _links, onOpenPairing: _openPairingId, onSelectTab: _select);
      case MyTab.requests:
        return RequestsTab(controller: _c, links: _links);
      case MyTab.calendar:
        return CalendarTab(
          controller: _c,
          links: _links,
          onRefresh: refresh,
          onOpenPairing: _openPairingId,
          onOpenPurchase: (_) => _select(MyTab.purchases),
          onOpenGroup: _openGroup,
        );
      case MyTab.purchases:
        return PurchasesTab(
          controller: _c,
          links: _links,
          onOpenGroup: _openGroup,
          onOpenPairing: _openPairingId,
          onOpenProgramme: _openProgramme,
          onBrowseGroups: () => openGroupSessions(context, links: _links),
          onBrowseProgrammes: () => openProgrammes(context, links: _links),
        );
      case MyTab.goals:
        return GoalsTab(controller: _c, onOpenPairing: _openPairingId);
      case MyTab.saved:
        return SavedTab(controller: _c, links: _links);
      case MyTab.certificates:
        return CertificatesTab(controller: _c, links: _links);
      case MyTab.reports:
        return ReportsTab(controller: _c, onOpenPairing: _openPairingId);
    }
  }

  Future<void> _openGroup(String id) async {
    await openGroupSession(context, id, links: _links);
    if (mounted) _c.refreshTab(MyTab.purchases);
  }

  Future<void> _openProgramme(String slug) async {
    await openProgramme(context, slug, links: _links);
    if (mounted) _c.refreshTab(MyTab.purchases);
  }

  Future<void> _openPairingId(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PairingScreen(id: id, links: _links, repository: _c.repository),
      ),
    );
    if (mounted) _c.refresh();
  }
}
