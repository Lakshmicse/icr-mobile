import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart';
import 'chapter_controller.dart';
import 'chapter_format.dart';
import 'chapter_models.dart';
import 'chapters_repository.dart';
import 'community_kit.dart';
import 'widgets/chapter_cover.dart';
import 'widgets/chapter_sections.dart';

/// Opens the phone's share sheet with a chapter's page link.
typedef ShareChapterLink = Future<void> Function(String title, Uri link);

Future<void> shareChapterLink(String title, Uri link) =>
    SharePlus.instance.share(ShareParams(text: '$title\n$link', subject: title)).then((_) {});

/// Where the Chapters screens hand a person on to: the shell wires each one. Kept in one value so a
/// chapter's page, opened from the board, from another chapter's page or from a notification, is given
/// the same ones.
class ChapterHandoffs {
  const ChapterHandoffs({
    required this.onOpenEvent,
    this.onOpenVolunteer,
    this.onBell,
    this.onOpenMember,
    this.onMessage,
    this.opener = openUrl,
    this.share = shareChapterLink,
  });

  /// A meetup was tapped, or its ticket asked for: the Events sheet, by the event's slug (else its id).
  final ValueChanged<String> onOpenEvent;

  /// "Get involved" / "Volunteer with this chapter": the Get Involved screen. The chapter's name when
  /// it was asked for from a chapter's page (to fill the application), null from the board.
  final ValueChanged<String?>? onOpenVolunteer;

  /// The bell. The website's notifications page when null.
  final VoidCallback? onBell;

  /// A committee member's or a roster row was tapped: their profile, by user id. Rows are not tappable without it.
  final ValueChanged<String>? onOpenMember;

  /// The message glyph on a committee row: a conversation with that user id. No glyph without it.
  final ValueChanged<String>? onMessage;

  /// Hands a page to the browser (or the mail app). Tests give their own.
  final Future<void> Function(BuildContext context, Uri uri) opener;

  /// Opens the phone's share sheet. Tests give their own.
  final ShareChapterLink share;
}

/// A chapter's page with its own [ChapterController] on [repository]: what the shell pushes for a chapter
/// named by its slug or id (a council's city tile, a notification, a card). [onChanged] tells the board
/// when the member's place changes.
Widget chapterPage({
  required ChaptersRepository repository,
  required String idOrSlug,
  required ChapterHandoffs handoffs,
  VoidCallback? onBack,
  ValueChanged<ChapterSummary>? onChanged,
  DateTime Function()? clock,
}) {
  return ChangeNotifierProvider<ChapterController>(
    create: (_) => ChapterController(repository: repository, idOrSlug: idOrSlug, onChanged: onChanged, clock: clock),
    child: Builder(
      builder: (context) => ChapterScreen(
        onBack: onBack ?? () => Navigator.of(context).pop(),
        onOpenEvent: handoffs.onOpenEvent,
        onOpenVolunteer: handoffs.onOpenVolunteer,
        onBell: handoffs.onBell,
        onOpenMember: handoffs.onOpenMember,
        onMessage: handoffs.onMessage,
        opener: handoffs.opener,
        share: handoffs.share,
      ),
    ),
  );
}

/// Pushes a chapter's page over the current screen. [idOrSlug] is what a chapter card, a notification
/// or a council's city tile names.
Future<void> openChapterPage(
  BuildContext context, {
  required ChaptersRepository repository,
  required String idOrSlug,
  required ChapterHandoffs handoffs,
  ValueChanged<ChapterSummary>? onChanged,
  DateTime Function()? clock,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (route) => chapterPage(
        repository: repository,
        idOrSlug: idOrSlug,
        handoffs: handoffs,
        onChanged: onChanged,
        clock: clock,
        onBack: () => Navigator.of(route).pop(),
      ),
    ),
  );
}

/// A chapter's page: the banner and numbers, then About, Leadership, Events,
/// Updates, Resources and the member roster, with Join and Leave on top.
///
/// Reads a [ChapterController] from Provider and starts it on first build.
class ChapterScreen extends StatefulWidget {
  const ChapterScreen({
    super.key,
    required this.onBack,
    required this.onOpenEvent,
    this.onOpenVolunteer,
    this.onBell,
    this.onOpenMember,
    this.onMessage,
    this.opener = openUrl,
    this.share = shareChapterLink,
  });

  final VoidCallback onBack;

  /// A meetup was tapped, or its ticket asked for: the shell shows the event (its slug, else its id).
  final ValueChanged<String> onOpenEvent;

  /// "Volunteer with this chapter", given the chapter's name; hidden when null.
  final ValueChanged<String?>? onOpenVolunteer;

  /// The bell; the website's notifications page when null.
  final VoidCallback? onBell;

  /// A committee or roster row opens the member's profile (their user id); rows are not tappable without it.
  final ValueChanged<String>? onOpenMember;

  /// The message glyph on a committee row (their user id); no glyph without it.
  final ValueChanged<String>? onMessage;
  final Future<void> Function(BuildContext context, Uri uri) opener;
  final ShareChapterLink share;

  ChapterHandoffs get _handoffs => ChapterHandoffs(
    onOpenEvent: onOpenEvent,
    onOpenVolunteer: onOpenVolunteer,
    onBell: onBell,
    onOpenMember: onOpenMember,
    onMessage: onMessage,
    opener: opener,
    share: share,
  );

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> {
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{
    'about': GlobalKey(),
    'leadership': GlobalKey(),
    'events': GlobalKey(),
    'updates': GlobalKey(),
    'resources': GlobalKey(),
    'members': GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    final page = context.read<ChapterController>();
    if (!page.started) page.start();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _bell() {
    final go = widget.onBell;
    if (go != null) return go();
    widget.opener(context, AppConfig.sitePage('/notifications'));
  }

  Future<void> _run(Future<String?> action) async {
    final message = await action;
    if (message != null && mounted) showMessage(context, message);
  }

  Future<void> _leave(ChapterController page) async {
    final name = page.chapter?.name ?? 'this chapter';
    final sure = await confirmDialog(
      context,
      title: 'Leave $name?',
      body: 'You will stop seeing its members-only updates. You can join again any time.',
      action: 'Leave',
    );
    if (sure && mounted) await _run(page.leave());
  }

  void _scrollTo(String section) {
    final ctx = _keys[section]?.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  void _openNearby(ChapterController page, ChapterSummary c) {
    openChapterPage(
      context,
      repository: page.repository,
      idOrSlug: c.slug,
      handoffs: widget._handoffs,
      onChanged: page.onChanged,
      clock: () => page.now,
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = context.watch<ChapterController>();
    return CommunityPage(
      title: page.chapter?.name ?? 'Chapter',
      onBack: widget.onBack,
      onBell: _bell,
      unread: page.unread,
      onRefresh: page.refresh,
      controller: _scroll,
      children: _body(page),
    );
  }

  List<Widget> _body(ChapterController page) {
    final detail = page.detail;
    if (detail == null) {
      if (page.loading || !page.started) return const [CommunityLoading()];
      return [
        CommunityNotice(
          icon: LucideIcons.cloudOff,
          title: "Couldn't load this chapter",
          body: page.error ?? 'Something went wrong.',
          action: 'Try again',
          onAction: page.refresh,
        ),
      ];
    }
    final c = detail.chapter;
    final stats = detail.stats;
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Hero(
            detail: detail,
            busy: page.busy,
            onJoin: () => _run(page.join()),
            onLeave: () => _leave(page),
            onShare: () => widget.share(c.name, page.repository.link(c)),
            onContact: detail.contactEmail == null
                ? null
                : () => widget.opener(context, Uri(scheme: 'mailto', path: detail.contactEmail)),
            onVolunteer: widget.onOpenVolunteer == null ? null : () => widget.onOpenVolunteer!(c.name),
          ),
          const SizedBox(height: 12),
          CommunityStatGrid(
            tiles: [
              CommunityStatTile(
                label: 'Active members',
                value: groupThousands(stats.memberCount),
                note: stats.leadershipCount > 0 ? '${stats.leadershipCount} on committee' : null,
              ),
              CommunityStatTile(label: 'Member companies', value: groupThousands(stats.memberCompanyCount)),
              CommunityStatTile(
                label: 'Upcoming events',
                value: groupThousands(stats.upcomingEventCount),
                blue: true,
                note: stats.upcomingEventCount > 0 ? 'RSVP open' : null,
              ),
              CommunityStatTile(
                label: 'Hosted sessions',
                value: groupThousands(stats.pastEventCount),
                note: detail.foundedYear == null ? null : 'since ${detail.foundedYear}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 31,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final (key, label) in const [
                  ('about', 'About'),
                  ('leadership', 'Leadership'),
                  ('events', 'Events'),
                  ('updates', 'Updates'),
                  ('resources', 'Resources'),
                  ('members', 'Members'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _NavChip(label: label, onTap: () => _scrollTo(key)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ChapterSectionFrame(
            sectionKey: _keys['about'],
            title: 'About',
            child: AboutSection(blocks: detail.about),
          ),
          if (detail.gallery.isNotEmpty)
            ChapterSectionFrame(
              title: 'Gallery',
              count: detail.gallery.length,
              child: GallerySection(pictures: detail.gallery),
            ),
          ChapterSectionFrame(
            sectionKey: _keys['leadership'],
            title: 'Leadership',
            count: detail.leads.length,
            child: LeadersSection(
              leads: detail.leads,
              onLinkedIn: (url) => widget.opener(context, Uri.parse(url)),
              onOpenMember: widget.onOpenMember,
              onMessage: widget.onMessage,
            ),
          ),
          ChapterSectionFrame(
            sectionKey: _keys['events'],
            title: 'Events & meetups',
            count: stats.upcomingEventCount,
            child: EventsSection(
              onOpenEvent: (e) => widget.onOpenEvent(e.key),
              onMessage: (m) => showMessage(context, m),
            ),
          ),
          ChapterSectionFrame(
            sectionKey: _keys['updates'],
            title: 'Updates',
            count: page.updates.items.length,
            child: const UpdatesSection(),
          ),
          ChapterSectionFrame(
            sectionKey: _keys['resources'],
            title: 'Resources',
            count: page.resources.items.length,
            child: ResourcesSection(onOpen: (r) => widget.opener(context, Uri.parse(r.url))),
          ),
          ChapterSectionFrame(
            sectionKey: _keys['members'],
            title: 'Members',
            count: stats.memberCount,
            child: MembersSection(onOpenMember: widget.onOpenMember),
          ),
          if (detail.sponsors.isNotEmpty)
            ChapterSectionFrame(
              title: 'Sponsors',
              child: SponsorsSection(
                sponsors: detail.sponsors,
                onOpen: (url) => widget.opener(context, Uri.parse(url)),
              ),
            ),
          if (page.nearby.isNotEmpty)
            ChapterSectionFrame(
              title: 'Other chapters in ${c.country}',
              child: NearbySection(chapters: page.nearby, onOpen: (n) => _openNearby(page, n)),
            ),
        ],
      ),
    ];
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({required this.label, required this.onTap});

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

/// The identity card: banner, the city's initial over its lower edge, name,
/// place, copy, and the actions (Join or Joined and Leave, Share, Contact).
class _Hero extends StatelessWidget {
  const _Hero({
    required this.detail,
    required this.busy,
    required this.onJoin,
    required this.onLeave,
    required this.onShare,
    required this.onContact,
    required this.onVolunteer,
  });

  final ChapterDetail detail;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onShare;
  final VoidCallback? onContact;
  final VoidCallback? onVolunteer;

  @override
  Widget build(BuildContext context) {
    final c = detail.chapter;
    final (from, _) = coverColors(c.slug);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ChapterCover(chapter: c, height: 104, tile: false),
            Positioned(
              left: 16,
              bottom: -30,
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [BoxShadow(color: Color(0x1F0F172A), blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: from.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Text(
                    c.city.isEmpty ? 'C' : c.city[0].toUpperCase(),
                    style: AppText.workSans(24, FontWeight.w700, from, lineHeight: 28),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 38, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: Text(c.name, style: CommunityText.cardTitleLarge)),
                  const SizedBox(width: 6),
                  const Tooltip(
                    message: 'Official ICR chapter',
                    child: Icon(LucideIcons.badgeCheck, size: 18, color: AppColors.primary),
                  ),
                ],
              ),
              if (c.region != null) ...[const SizedBox(height: 2), Text(c.region!, style: CommunityText.personRole)],
              const SizedBox(height: 6),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.mapPin, size: 12, color: AppColors.slate400),
                      const SizedBox(width: 4),
                      Text(c.place, style: CommunityText.personLine),
                    ],
                  ),
                  if (detail.foundedYear != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.calendar, size: 12, color: AppColors.slate400),
                        const SizedBox(width: 4),
                        Text(establishedLabel(detail.foundedYear!), style: CommunityText.personLine),
                      ],
                    ),
                ],
              ),
              if (c.description != null) ...[
                const SizedBox(height: 8),
                Text(c.description!, style: CommunityText.body),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: c.joined
                        ? Row(
                            children: [
                              CommunityPill(
                                label: c.role == ChapterRole.lead ? 'Chapter lead' : 'Joined',
                                icon: LucideIcons.check,
                                fill: CommunityColors.green50,
                                style: CommunityText.pill.copyWith(color: CommunityColors.green700),
                                height: 30,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                border: CommunityColors.green200,
                              ),
                              // A chapter lead has no Leave, as on the website: leaving would drop the
                              // committee seat, and stepping down is the chapter's to arrange.
                              if (c.role != ChapterRole.lead) ...[
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
                            label: 'Join Chapter',
                            icon: LucideIcons.userPlus,
                            busy: busy,
                            expand: true,
                            height: 34,
                            onPressed: onJoin,
                          ),
                  ),
                  const SizedBox(width: 8),
                  _RoundAction(icon: LucideIcons.share2, label: 'Share chapter', onTap: onShare),
                  if (onContact != null) ...[
                    const SizedBox(width: 6),
                    _RoundAction(icon: LucideIcons.mail, label: 'Email the chapter', onTap: onContact!),
                  ],
                ],
              ),
              if (onVolunteer != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onVolunteer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.handHeart, size: 13, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text('Volunteer with this chapter', style: CommunityText.link),
                      ],
                    ),
                  ),
                ),
              ],
            ],
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
