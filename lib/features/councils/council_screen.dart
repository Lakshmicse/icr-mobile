import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/manage_pencil.dart';
import '../chapters/community_kit.dart';
import '../chapters/resource_download.dart';
import '../chapters/widgets/chapter_sections.dart' show ChapterSectionFrame, GallerySection;
import '../shell/app_shell.dart';
import 'council_controller.dart';
import 'council_models.dart';
import 'councils_repository.dart';
import 'councils_styles.dart';
import 'widgets/council_sections.dart';
import 'widgets/pills.dart' show CouncilCover, IndustryGlyph;

/// Opens the phone's share sheet with a council's page link.
typedef ShareCouncilLink = Future<void> Function(String title, Uri link);

Future<void> shareCouncilLink(String title, Uri link) =>
    SharePlus.instance.share(ShareParams(text: '$title\n$link', subject: title)).then((_) {});

/// Where a council's page hands a person on to: the shell wires each one. Kept in one value so the page, opened
/// from the board, from a link on the website or from a notification, is given the same ones.
class CouncilHandoffs {
  const CouncilHandoffs({
    required this.onOpenEvent,
    this.onBell,
    this.onOpenMember,
    this.onMessage,
    this.opener = openUrl,
    this.share = shareCouncilLink,
    this.downloader = const SystemResourceDownloader(),
    this.manage,
    this.pageWrap = plainPage,
  });

  /// The pencil beside the bell, for the staff who may manage the council; no pencil without it.
  final RecordManage? manage;

  /// Frames a council's page pushed from the board or a link (the app's bottom bar under it).
  final PageWrap pageWrap;

  /// A session was tapped: the Events sheet, by the event's slug (else its id).
  final ValueChanged<String> onOpenEvent;

  /// The bell. The website's notifications page when null.
  final VoidCallback? onBell;

  /// A leader's or a roster row was tapped: their profile, by user id. Rows are not tappable without it.
  final ValueChanged<String>? onOpenMember;

  /// The message glyph on a leader's row: a conversation with that user id. No glyph without it.
  final ValueChanged<String>? onMessage;

  /// Hands a page to the browser (or the mail app): a file, a LinkedIn profile. Tests give their own.
  final Future<void> Function(BuildContext context, Uri uri) opener;

  /// Opens the phone's share sheet. Tests give their own.
  final ShareCouncilLink share;

  /// Saves a resource's file to the phone (the Knowledge library's Download). Tests give their own.
  final ResourceDownloader downloader;

  CouncilHandoffs withOpener(Future<void> Function(BuildContext context, Uri uri) opener) => CouncilHandoffs(
    onOpenEvent: onOpenEvent,
    onBell: onBell,
    onOpenMember: onOpenMember,
    onMessage: onMessage,
    opener: opener,
    share: share,
    downloader: downloader,
    manage: manage,
    pageWrap: pageWrap,
  );
}

/// A council's page with its own [CouncilController] on [repository]: what the shell pushes for a council named
/// by its slug or id (a card, a notification, a link). [tab] is the website's `?tab=` and opens the page on that
/// section. [onChanged] tells the board when the member's seat changes.
Widget councilPage({
  required CouncilPageRepository repository,
  required String idOrSlug,
  required CouncilHandoffs handoffs,
  String? tab,
  VoidCallback? onBack,
  ValueChanged<Council>? onChanged,
  DateTime Function()? clock,
}) {
  return ChangeNotifierProvider<CouncilController>(
    create: (_) => CouncilController(repository: repository, idOrSlug: idOrSlug, onChanged: onChanged, clock: clock),
    child: Builder(
      builder: (context) =>
          CouncilScreen(onBack: onBack ?? () => Navigator.of(context).pop(), handoffs: handoffs, tab: tab),
    ),
  );
}

/// Pushes a council's page over the current screen. [idOrSlug] is what a council card, a notification or a
/// `/councils/<slug>` link names; [tab] one of the website's tabs (`events`, `leadership`, `members`, `knowledge`,
/// `updates`).
Future<void> openCouncilPage(
  BuildContext context, {
  required CouncilPageRepository repository,
  required String idOrSlug,
  required CouncilHandoffs handoffs,
  String? tab,
  ValueChanged<Council>? onChanged,
  DateTime Function()? clock,
}) {
  // Through the shell, so the bottom bar under the page (the handoffs' frame) still reaches its tabs.
  return AppShell.push<void>(
    context,
    (route) => handoffs.pageWrap(
      councilPage(
        repository: repository,
        idOrSlug: idOrSlug,
        handoffs: handoffs,
        tab: tab,
        onChanged: onChanged,
        clock: clock,
        onBack: () => Navigator.of(route).pop(),
      ),
    ),
  );
}

/// A council's own page, as the website's `/councils/<slug>`: the banner and figures, then Overview, Events,
/// Leadership, Members, Knowledge and Updates (and the gallery, when it has one), with Join and Leave on top.
/// The chapter's page is its twin.
///
/// Reads a [CouncilController] from Provider and starts it on first build. A page opened on a tab scrolls to
/// that section once the council and its sections have answered, unless the reader has already scrolled.
class CouncilScreen extends StatefulWidget {
  const CouncilScreen({super.key, required this.onBack, required this.handoffs, this.tab});

  final VoidCallback onBack;
  final CouncilHandoffs handoffs;

  /// The website's `?tab=`; an unknown one is ignored.
  final String? tab;

  @override
  State<CouncilScreen> createState() => _CouncilScreenState();
}

class _CouncilScreenState extends State<CouncilScreen> {
  final _scroll = ScrollController();
  final _keys = {for (final s in CouncilSection.values) s: GlobalKey()};
  CouncilSection? _landOn;

  CouncilHandoffs get _h => widget.handoffs;

  @override
  void initState() {
    super.initState();
    _landOn = CouncilSection.fromTab(widget.tab);
    final page = context.read<CouncilController>();
    if (!page.started) page.start();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _bell() {
    final go = _h.onBell;
    if (go != null) return go();
    _h.opener(context, AppConfig.sitePage('/notifications'));
  }

  Future<void> _run(Future<String?> action) async {
    final message = await action;
    if (message != null && mounted) showMessage(context, message);
  }

  Future<void> _leave(CouncilController page) async {
    final name = page.council?.name ?? 'this council';
    final sure = await confirmDialog(
      context,
      title: 'Leave $name?',
      body: 'You will stop seeing its members-only sessions and updates. You can join again any time.',
      action: 'Leave',
    );
    if (sure && mounted) await _run(page.leave());
  }

  void _scrollTo(CouncilSection section, {bool animate = true}) {
    final ctx = _keys[section]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: animate ? const Duration(milliseconds: 280) : Duration.zero,
      curve: Curves.easeOut,
    );
  }

  /// Opens the page on the section its link named, once the sections have the height they will keep. A reader
  /// who has already moved the page has chosen where to be.
  void _land() {
    final section = _landOn;
    if (section == null) return;
    _landOn = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || (_scroll.hasClients && _scroll.offset > 24)) return;
      _scrollTo(section, animate: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = context.watch<CouncilController>();
    if (page.settled) _land();
    return CommunityPage(
      // The bar fits a word, not a council's name ("Corporate & Commercial Real Estate Council"): the name is the
      // banner's, just under it.
      title: 'Council',
      onBack: widget.onBack,
      onBell: _bell,
      actions: [
        if (_h.manage != null && page.council != null)
          ManagePencil(manage: _h.manage!, id: page.council!.id, label: 'Manage council'),
      ],
      unread: page.unread,
      onRefresh: page.refresh,
      controller: _scroll,
      children: _body(page),
    );
  }

  List<Widget> _body(CouncilController page) {
    final detail = page.detail;
    if (detail == null) {
      if (page.loading || !page.started) return const [CommunityLoading()];
      return [
        CommunityNotice(
          icon: LucideIcons.cloudOff,
          title: 'Unable to Load This Council',
          body: page.error ?? 'Something went wrong.',
          action: 'Try Again',
          onAction: page.refresh,
        ),
      ];
    }
    final c = detail.council;
    final stats = detail.stats;
    final sections = [
      for (final s in CouncilSection.values)
        if (s != CouncilSection.gallery || detail.gallery.isNotEmpty) s,
    ];
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Hero(
            detail: detail,
            busy: page.busy,
            onJoin: () => _run(page.join()),
            onLeave: () => _leave(page),
            onShare: () => _h.share(c.name, page.repository.link(c)),
            onContact: detail.contactEmail == null
                ? null
                : () => _h.opener(context, Uri(scheme: 'mailto', path: detail.contactEmail)),
          ),
          const SizedBox(height: 12),
          CommunityStatGrid(
            tiles: [
              CommunityStatTile(label: 'Members', value: groupThousands(stats.memberCount)),
              CommunityStatTile(label: 'Companies', value: groupThousands(stats.memberCompanyCount)),
              CommunityStatTile(
                label: 'Upcoming Events',
                value: groupThousands(stats.upcomingEventCount),
                blue: true,
                note: stats.upcomingEventCount > 0 ? 'RSVP open' : null,
              ),
              CommunityStatTile(label: 'Events Hosted', value: groupThousands(stats.pastEventCount)),
              CommunityStatTile(label: 'Leadership', value: groupThousands(stats.leadershipCount)),
            ],
          ),
          const SizedBox(height: 12),
          // A few short chips, so a row that scrolls sideways rather than a lazy list: every chip exists.
          SizedBox(
            height: 31,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final s in sections)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _NavChip(key: ValueKey('chip-${s.tab}'), label: s.label, onTap: () => _scrollTo(s)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ChapterSectionFrame(
            sectionKey: _keys[CouncilSection.overview],
            title: 'About This Council',
            child: CouncilOverviewSection(blocks: detail.about, segments: c.segments),
          ),
          ChapterSectionFrame(
            sectionKey: _keys[CouncilSection.events],
            title: 'Events',
            count: stats.upcomingEventCount,
            child: CouncilEventsSection(onOpenEvent: (e) => _h.onOpenEvent(e.key)),
          ),
          ChapterSectionFrame(
            sectionKey: _keys[CouncilSection.leadership],
            title: 'Council Leadership',
            count: detail.leads.length,
            child: CouncilLeadershipSection(
              leads: detail.leads,
              onLinkedIn: (url) => _h.opener(context, Uri.parse(url)),
              onOpenMember: _h.onOpenMember,
              onMessage: _h.onMessage,
            ),
          ),
          ChapterSectionFrame(
            sectionKey: _keys[CouncilSection.members],
            title: 'Members',
            count: stats.memberCount,
            child: CouncilMembersSection(onOpenMember: _h.onOpenMember),
          ),
          ChapterSectionFrame(
            sectionKey: _keys[CouncilSection.knowledge],
            title: 'Knowledge Library',
            count: page.resources.items.length,
            child: CouncilKnowledgeSection(downloader: _h.downloader, opener: _h.opener),
          ),
          ChapterSectionFrame(
            sectionKey: _keys[CouncilSection.updates],
            title: 'News & Updates',
            count: page.updates.items.length,
            child: const CouncilUpdatesSection(),
          ),
          if (detail.gallery.isNotEmpty)
            ChapterSectionFrame(
              sectionKey: _keys[CouncilSection.gallery],
              title: 'Gallery',
              count: detail.gallery.length,
              child: GallerySection(pictures: detail.gallery),
            ),
        ],
      ),
    ];
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Go to $label',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15.5),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Text(label, style: CommunityText.chip),
        ),
      ),
    );
  }
}

/// The identity card: the cover with the industry's glyph, the name, the categories, the copy and the chair, and
/// the actions (Join Council or Joined and Leave, Share, Email).
class _Hero extends StatelessWidget {
  const _Hero({
    required this.detail,
    required this.busy,
    required this.onJoin,
    required this.onLeave,
    required this.onShare,
    required this.onContact,
  });

  final CouncilDetail detail;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onShare;
  final VoidCallback? onContact;

  @override
  Widget build(BuildContext context) {
    final c = detail.council;
    final chair = c.chair;
    final copy = c.description ?? c.focus;
    final lead = c.membership == CouncilRole.lead;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            CouncilCover(council: c, height: 104),
            Positioned(
              left: 13,
              top: 11,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: CouncilsColors.coverTile, borderRadius: BorderRadius.circular(7)),
                child: Center(child: IndustryGlyph(c.industry)),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: Text(c.name, style: CommunityText.cardTitleLarge)),
                  const SizedBox(width: 6),
                  const Tooltip(
                    message: 'Official ICR Council',
                    child: Icon(LucideIcons.badgeCheck, size: 18, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text('Industry Council', style: CommunityText.personRole),
              if (c.segments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final s in c.segments.take(6))
                      CommunityPill(
                        label: s,
                        fill: CommunityColors.tagFill,
                        style: CommunityText.tag,
                        height: 17,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                  ],
                ),
              ],
              if (copy != null) ...[const SizedBox(height: 8), Text(copy, style: CommunityText.body)],
              if (chair != null && chair.name.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _ChairRow(chair: chair),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: c.joined
                        ? Row(
                            children: [
                              CommunityPill(
                                label: lead ? 'Council Lead' : 'Joined',
                                icon: LucideIcons.check,
                                fill: CommunityColors.green50,
                                style: CommunityText.pill.copyWith(color: CommunityColors.green700),
                                height: 30,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                border: CommunityColors.green200,
                              ),
                              // A council lead has no Leave, as on the website: stepping down is the council's
                              // to arrange (the Your councils sheet on the board still offers it).
                              if (!lead) ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: busy ? null : onLeave,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text('Leave', style: CommunityText.buttonQuiet),
                                  ),
                                ),
                              ],
                            ],
                          )
                        : CommunityButton(
                            label: 'Join Council',
                            icon: LucideIcons.userPlus,
                            busy: busy,
                            expand: true,
                            height: 34,
                            onPressed: onJoin,
                          ),
                  ),
                  const SizedBox(width: 8),
                  _RoundAction(icon: LucideIcons.share2, label: 'Share council', onTap: onShare),
                  if (onContact != null) ...[
                    const SizedBox(width: 6),
                    _RoundAction(icon: LucideIcons.mail, label: 'Email the council', onTap: onContact!),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Chaired by Vikram Malhotra · Director ESG @ DLF", with the chair's photo.
class _ChairRow extends StatelessWidget {
  const _ChairRow({required this.chair});

  final CouncilChair chair;

  @override
  Widget build(BuildContext context) {
    final words = chair.name.split(' ').where((w) => w.isNotEmpty).toList();
    final title = chair.title?.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Row(
      children: [
        PersonAvatar(
          initials: initialsOf(words.first, words.length > 1 ? words.last : ''),
          photo: chair.photo,
          size: 28,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Chaired by '),
                TextSpan(text: chair.name, style: CommunityText.metaStrong),
                if (title != null && title.isNotEmpty) TextSpan(text: ' · $title'),
              ],
            ),
            style: CommunityText.personLine,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: CommunityColors.border),
          ),
          child: Icon(icon, size: 15, color: AppColors.slate600),
        ),
      ),
    );
  }
}
