import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../mentorship_my/mentoring_links.dart';
import '../mentorship_my/my_mentoring_tabs.dart' show CalendarTab;
import '../mentorship_my/pairing_screen.dart';
import '../mentorship_my/widgets/kit.dart';
import 'desk_overview_tab.dart';
import 'desk_people_tabs.dart';
import 'desk_requests_tab.dart';
import 'desk_setup_tabs.dart';
import 'desk_work_tab.dart';
import 'mentor_desk_controller.dart';
import 'mentor_desk_models.dart';
import 'mentor_desk_repository.dart';
import 'offerings/offerings_panel.dart';

/// Pushes the mentor's desk, optionally on one tab.
Future<void> openMentorDesk(
  BuildContext context, {
  DeskTab tab = DeskTab.overview,
  MentorshipLinks? links,
  VoidCallback? onBack,
  OpenConversation? onOpenConversation,
  void Function(BuildContext context, String mentorProfileId)? onOpenMentor,
  void Function(BuildContext context)? onBell,
  OpenSitePath? onOpenWebsite,
  void Function(BuildContext context)? onBecomeMentor,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => MentorDeskScreen(
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
      onBecomeMentor: onBecomeMentor,
    ),
  ),
);

/// The mentor's desk (the website's `/mentorship/mentor`): what is asked of them, their mentees, calendar, paid
/// work, offerings, weekly hours, earnings, reviews and settings. It is for a mentor whose profile ICR
/// approved: without a profile (or with one still in review) it says so and offers [onBecomeMentor].
///
/// "Message" opens a thread through the record, as in My mentoring: [onOpenConversation] (or the links'
/// `openPairingThread` / `openPurchaseThread`) is the messaging feature's chat screen.
class MentorDeskScreen extends StatefulWidget {
  const MentorDeskScreen({
    super.key,
    this.onBack,
    this.links,
    this.repository,
    this.onOpenConversation,
    this.onOpenMentor,
    this.onBell,
    this.onOpenWebsite,
    this.onBecomeMentor,
    this.initialTab = DeskTab.overview,
  });

  final VoidCallback? onBack;
  final MentorshipLinks? links;

  /// A seam for tests; the API by default.
  final MentorDeskRepository? repository;

  /// Opens the messaging feature's chat for a conversation id.
  final OpenConversation? onOpenConversation;

  /// Opens a mentor's profile by mentor profile id.
  final void Function(BuildContext context, String mentorProfileId)? onOpenMentor;

  /// The bell.
  final void Function(BuildContext context)? onBell;

  /// Opens a page of the website (a path such as `/profile`): the few things the app hands over.
  final OpenSitePath? onOpenWebsite;

  /// "Become a mentor" / "Continue your application": the lead wires it to the become-a-mentor screen.
  final void Function(BuildContext context)? onBecomeMentor;

  final DeskTab initialTab;

  @override
  State<MentorDeskScreen> createState() => _MentorDeskScreenState();
}

class _MentorDeskScreenState extends State<MentorDeskScreen> {
  late final MentorDeskController _c;
  late final MentorshipLinks _links;
  late DeskTab _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    final repo = widget.repository ?? MentorDeskRepository(api: context.read<ApiClient>());
    _links = MentorshipLinks.resolve(
      context,
      widget.links,
      onOpenConversation: widget.onOpenConversation,
      onOpenMentor: widget.onOpenMentor,
      onBell: widget.onBell,
      onOpenWebsite: widget.onOpenWebsite,
    );
    _c = MentorDeskController(repo)..start().then((_) => _c.ensureTab(_tab));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _select(DeskTab tab) {
    setState(() => _tab = tab);
    _c.ensureTab(tab);
  }

  Future<void> _openPairing(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PairingScreen(id: id, links: _links, repository: _c.repository.mentoring),
      ),
    );
    if (mounted) _c.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        return MentoringPage(
          title: 'Mentor desk',
          onBack: widget.onBack,
          onBell: () => _links.notifications(context),
          body: switch (_c.gate) {
            DeskGate.loading => LoadedList(loading: true, error: null, onRefresh: _c.refresh, children: const []),
            DeskGate.failed => LoadedList(
              loading: false,
              error: _c.dashboard.error,
              errorTitle: "Couldn't load your desk",
              onRefresh: _c.refresh,
              children: const [],
            ),
            DeskGate.noProfile ||
            DeskGate.notLive => _NotYet(controller: _c, onBecomeMentor: widget.onBecomeMentor, onRefresh: _c.refresh),
            DeskGate.ready => _desk(context),
          },
        );
      },
    );
  }

  Widget _desk(BuildContext context) {
    final profile = _c.profile!;
    final badges = [
      for (final t in DeskTab.values)
        switch (t) {
          DeskTab.requests => _c.requestCount,
          DeskTab.work => _c.workCount,
          _ => 0,
        },
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: SegmentTabs(
            labels: [for (final t in DeskTab.values) t.label],
            selected: DeskTab.values.indexOf(_tab),
            onSelect: (i) => _select(DeskTab.values[i]),
            badges: badges,
          ),
        ),
        Expanded(child: _body(context, profile)),
      ],
    );
  }

  Widget _body(BuildContext context, DeskProfile profile) {
    switch (_tab) {
      case DeskTab.overview:
        return OverviewTab(
          controller: _c,
          links: _links,
          onSelectTab: _select,
          onOpenPairing: _openPairing,
          onBecomeMentor: widget.onBecomeMentor,
        );
      case DeskTab.requests:
        return DeskRequestsTab(controller: _c, links: _links);
      case DeskTab.mentees:
        return DeskMenteesTab(controller: _c, links: _links, onOpenPairing: _openPairing);
      case DeskTab.calendar:
        return CalendarTab(
          controller: _c.mentoring,
          links: _links,
          onRefresh: () => _c.refreshTab(DeskTab.calendar),
          onOpenPairing: _openPairing,
          onOpenPurchase: (_) => _select(DeskTab.work),
          onOpenGroup: (_) => _select(DeskTab.offerings),
        );
      case DeskTab.work:
        return DeskWorkTab(controller: _c, links: _links, onOpenPairing: _openPairing);
      case DeskTab.offerings:
        return OfferingsPanel(api: _c.repository.api, links: _links, onChanged: _c.refresh);
      case DeskTab.hours:
        return DeskHoursTab(controller: _c);
      case DeskTab.earnings:
        return DeskEarningsTab(controller: _c);
      case DeskTab.reviews:
        return DeskReviewsTab(controller: _c);
      case DeskTab.settings:
        return DeskSettingsTab(controller: _c);
    }
  }
}

/// A member with no mentor profile (or one still being reviewed): the desk is not theirs yet.
class _NotYet extends StatelessWidget {
  const _NotYet({required this.controller, required this.onBecomeMentor, required this.onRefresh});

  final MentorDeskController controller;
  final void Function(BuildContext context)? onBecomeMentor;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final d = controller.dashboard.data;
    final status = d?.profile?.status;
    final none = d == null || !d.hasProfile;
    final (title, body, button) = none
        ? (
            "You're not a mentor yet",
            'Build a mentor profile and, once ICR approves it, this is where you run your mentoring: requests, mentees, calendar, hours and earnings.',
            'Become a mentor',
          )
        : switch (status) {
            DeskStatus.pending => (
              'Your application is in review',
              'ICR is reading your mentor profile. The desk opens when it is approved.',
              'See my application',
            ),
            DeskStatus.rejected => (
              'Your application was not approved',
              d.profile?.reviewNote ?? 'You can change your profile and send it again.',
              'Change my application',
            ),
            _ => (
              'Finish your application',
              'Your mentor profile is a draft. Complete it and send it to ICR; the desk opens once it is approved.',
              'Continue your application',
            ),
          };
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EmptyNote(icon: LucideIcons.handshake, title: title, body: body),
          if (d != null && d.hasProfile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Center(
                child: StatusPill(
                  'Status: ${status?.label ?? 'Unknown'}',
                  tone: status == DeskStatus.rejected ? PillTone.red : PillTone.amber,
                ),
              ),
            ),
          if (onBecomeMentor != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
              child: Center(
                child: SolidButton(label: button, onPressed: () => onBecomeMentor!(context)),
              ),
            ),
        ],
      ),
    );
  }
}
