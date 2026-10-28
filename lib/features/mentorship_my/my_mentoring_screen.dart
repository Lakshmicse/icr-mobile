import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/util/links.dart';
import 'mentoring_format.dart';
import 'mentoring_links.dart';
import 'mentoring_models.dart';
import 'mentoring_repository.dart';
import 'my_mentoring_controller.dart';
import 'group_sessions_screen.dart';
import 'pairing_screen.dart';
import 'programmes_screen.dart';
import 'my_mentoring_tabs.dart';
import 'purchases_tab.dart';
import 'widgets/blocks.dart';
import 'widgets/kit.dart';
import 'mentoring_clock.dart';

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
        return MentoringPage(
          title: 'My Mentoring',
          onBack: widget.onBack,
          onBell: () => _links.notifications(context),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: SegmentTabs(
                  labels: [for (final t in tabs) t.label],
                  selected: tabs.indexOf(_tab).clamp(0, tabs.length - 1),
                  onSelect: (i) => _select(tabs[i]),
                  badges: badges,
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
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
        return _MentoringTab(controller: _c, links: _links, onOpenPairing: _openPairingId, onSelectTab: _select);
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

/// The first tab: what needs the member, what is next, and their pairings.
class _MentoringTab extends StatelessWidget {
  const _MentoringTab({
    required this.controller,
    required this.links,
    required this.onOpenPairing,
    required this.onSelectTab,
  });

  final MyMentoringController controller;
  final MentorshipLinks links;
  final ValueChanged<String> onOpenPairing;
  final ValueChanged<MyTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final loading = !c.pairings.loaded && c.pairings.loading;
    final live = c.livePairings;
    final finished = c.finishedPairings;
    final asMentor = live.where((p) => p.viewerIsMentor).toList();
    final asMentee = live.where((p) => !p.viewerIsMentor).toList();
    final summary = c.summary.data;
    final nextUp = [
      for (final s in c.upcoming.data ?? const <PairingSession>[])
        if (s.upcoming(mentoringNow())) s,
    ];
    nextUp.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final needs = <NeedItem>[
      if (c.pendingReceived.isNotEmpty)
        NeedItem(
          icon: LucideIcons.inbox,
          text: '${countLabel(c.pendingReceived.length, 'mentoring request')} to answer',
          onTap: () => onSelectTab(MyTab.requests),
        ),
      if (c.pendingSent.isNotEmpty)
        NeedItem(
          icon: LucideIcons.hourglass,
          text: '${countLabel(c.pendingSent.length, 'request')} waiting for a mentor to reply',
          onTap: () => onSelectTab(MyTab.requests),
          tone: PillTone.grey,
        ),
      for (final s in nextUp.where((s) => s.scheduledAt.difference(mentoringNow()).inHours < 24).take(2))
        NeedItem(
          icon: LucideIcons.calendarClock,
          text:
              'Session ${daysFromNow(s.scheduledAt)} at ${timeLabel(s.scheduledAt)}'
              '${s.counterpart == null ? '' : ' with ${s.counterpart!.firstName}'}',
          onTap: () => onSelectTab(MyTab.calendar),
        ),
    ];

    final children = <Widget>[
      if (summary != null)
        StatStrip(
          tiles: [
            ('${summary.activeAsMentee + summary.activeAsMentor}', 'Live pairings'),
            ('${summary.pendingIncoming + summary.pendingOutgoing}', 'Open requests'),
            ('${nextUp.length}', 'Sessions ahead'),
          ],
        ),
      NeedsYouCard(items: needs, clear: 'Nothing is waiting on you.'),
      if (nextUp.isNotEmpty) ...[
        const SectionTitle(title: 'Up next', top: 6),
        _UpNext(session: nextUp.first, links: links, onOpen: () => onOpenPairing(nextUp.first.mentorshipId)),
      ],
      if (asMentee.isNotEmpty) ...[
        SectionTitle(title: asMentor.isEmpty ? 'Your mentors' : 'Mentors you learn from', top: 14),
        for (final p in asMentee) _card(context, p),
      ],
      if (asMentor.isNotEmpty) ...[
        SectionTitle(title: 'Your mentees', top: 14),
        for (final p in asMentor) _card(context, p),
      ],
      if (live.isEmpty && c.pairings.loaded)
        EmptyNote(
          icon: LucideIcons.handshake,
          compact: true,
          title: 'No mentor yet',
          body: 'Ask a mentor to guide you. Most replies come within a few days.',
        ),
      if (finished.isNotEmpty) ...[
        const SectionTitle(title: 'Finished', top: 14),
        for (final p in finished) _card(context, p),
      ],
      BlueBand(
        kicker: 'Mentoring',
        title: live.isEmpty ? 'Find your first mentor' : 'Find another mentor',
        body: 'Browse people who have done the job you want, by domain, company or years of experience.',
        buttonLabel: 'Find a mentor',
        icon: LucideIcons.search,
        onPressed: () => links.directory(context),
      ),
    ];

    return LoadedList(
      loading: loading,
      error: c.pairings.error,
      errorTitle: "Couldn't load your mentoring",
      onRefresh: c.refresh,
      children: loading || (c.pairings.error != null && !c.pairings.loaded) ? const [] : children,
    );
  }

  Widget _card(BuildContext context, Pairing p) => PairingCard(
    pairing: p,
    next: controller.nextSessionOf(p.id),
    onOpen: () => onOpenPairing(p.id),
    onMessage: () => links.messagePairing(context, controller.repository, p.id),
  );
}

class _UpNext extends StatelessWidget {
  const _UpNext({required this.session, required this.links, required this.onOpen});

  final PairingSession session;
  final MentorshipLinks links;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final link = meetingUri(s.meetingLink);
    return MentoringCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(whenLabel(s.scheduledAt), style: MentoringText.cardTitle)),
              StatusPill(daysFromNow(s.scheduledAt), tone: PillTone.mint),
            ],
          ),
          MetaLine(
            icon: LucideIcons.user,
            text:
                '${s.counterpart?.name ?? 'Your mentoring session'} · ${minutesLabel(s.durationMin)} · ${modeLabel(s.mode)}',
          ),
          if (s.agenda != null && s.agenda!.isNotEmpty) MetaLine(icon: LucideIcons.notebookPen, text: s.agenda!),
          if (link != null)
            ActionWrap(
              children: [SolidButton(label: 'Join', icon: LucideIcons.video, onPressed: () => openUrl(context, link))],
            ),
        ],
      ),
    );
  }
}
