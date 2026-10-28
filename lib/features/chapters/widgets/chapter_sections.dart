import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../chapter_controller.dart';
import '../chapter_format.dart';
import '../chapter_models.dart';
import '../community_kit.dart';
import 'chapter_cover.dart';
import 'meetup_row.dart';

/// One titled section of a chapter's page, with the keys the section chips
/// scroll to. [count] is the pill after the title.
class ChapterSectionFrame extends StatelessWidget {
  const ChapterSectionFrame({super.key, required this.title, required this.child, this.count, this.sectionKey});

  final String title;
  final int? count;
  final Widget child;

  /// What the section chips scroll to.
  final GlobalKey? sectionKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: sectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, thickness: 1, color: CommunityColors.tileRule),
        const SizedBox(height: 16),
        CommunitySectionHeading(title: title, pill: count == null || count == 0 ? null : groupThousands(count!)),
        const SizedBox(height: 10),
        child,
        const SizedBox(height: 18),
      ],
    );
  }
}

/// A quiet line for a section with nothing in it.
class SectionEmpty extends StatelessWidget {
  const SectionEmpty(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Text(text, style: CommunityText.small),
  );
}

/// A section's own failure, with its own Try again, so the rest of the page stands.
class SectionFailed extends StatelessWidget {
  const SectionFailed({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(LucideIcons.circleAlert, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: CommunityText.fieldError)),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRetry,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Try again', style: CommunityText.link),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionLoading extends StatelessWidget {
  const SectionLoading({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 18),
    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
  );
}

// ---------------------------------------------------------------------------
// About, gallery
// ---------------------------------------------------------------------------

class AboutSection extends StatelessWidget {
  const AboutSection({super.key, required this.blocks});

  final List<AboutBlock> blocks;

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) return const SectionEmpty('This chapter has not written its About text yet.');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final b in blocks)
            switch (b.kind) {
              AboutKind.heading => Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Text(b.text, style: CommunityText.personName),
              ),
              AboutKind.paragraph => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(b.text, style: CommunityText.body),
              ),
              AboutKind.bullet => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7, right: 8, left: 2),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      ),
                    ),
                    Expanded(child: Text(b.text, style: CommunityText.body)),
                  ],
                ),
              ),
            },
        ],
      ),
    );
  }
}

class GallerySection extends StatelessWidget {
  const GallerySection({super.key, required this.pictures});

  final List<FeedPicture> pictures;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: pictures.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => _show(context, pictures[i]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 128, height: 96, child: _image(pictures[i], BoxFit.cover)),
          ),
        ),
      ),
    );
  }

  static Widget _image(FeedPicture p, BoxFit fit) => p.asset != null
      ? Image.asset(p.asset!, fit: fit)
      : CachedNetworkImage(
          imageUrl: p.url!,
          fit: fit,
          placeholder: (_, _) => const ColoredBox(color: CommunityColors.greyPill),
          errorWidget: (_, _, _) => const ColoredBox(
            color: CommunityColors.greyPill,
            child: Center(child: Icon(LucideIcons.imageOff, size: 20, color: AppColors.slate400)),
          ),
        );

  void _show(BuildContext context, FeedPicture p) {
    showDialog<void>(
      context: context,
      builder: (dialog) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(child: Center(child: _image(p, BoxFit.contain))),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Close',
                icon: const Icon(LucideIcons.x, color: Colors.white),
                onPressed: () => Navigator.pop(dialog),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// People
// ---------------------------------------------------------------------------

/// A committee member or roster row.
class PersonRow extends StatelessWidget {
  const PersonRow({super.key, required this.person, this.onLinkedIn, this.onOpen, this.onMessage});

  final ChapterPerson person;
  final VoidCallback? onLinkedIn;

  /// The row opens the member's profile (the shell's callback); not tappable without one.
  final VoidCallback? onOpen;

  /// A message to this person (the shell's messaging); no glyph without one.
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final p = person;
    final line = [if (p.title != null) p.title!, if (p.company != null) p.company!].join(' · ');
    return InkWell(
      onTap: onOpen,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: _row(p, line)),
    );
  }

  Widget _row(ChapterPerson p, String line) {
    return Row(
      children: [
        PersonAvatar(initials: p.initials, photo: p.photo, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(p.name, style: CommunityText.personName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (p.role == ChapterRole.lead) ...[
                    const SizedBox(width: 5),
                    const Icon(LucideIcons.badgeCheck, size: 14, color: AppColors.primary),
                  ],
                ],
              ),
              if (line.isNotEmpty)
                Text(line, style: CommunityText.personLine, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (p.joinedAt != null) Text(joinedLabel(p.joinedAt!), style: CommunityText.meta),
            ],
          ),
        ),
        if (onMessage != null)
          IconButton(
            tooltip: 'Message ${p.name}',
            visualDensity: VisualDensity.compact,
            icon: const Icon(LucideIcons.messageCircle, size: 16, color: AppColors.slate500),
            onPressed: onMessage,
          ),
        if (onLinkedIn != null)
          IconButton(
            tooltip: 'LinkedIn profile of ${p.name}',
            visualDensity: VisualDensity.compact,
            icon: const Icon(LucideIcons.link, size: 16, color: AppColors.slate500),
            onPressed: onLinkedIn,
          ),
      ],
    );
  }
}

class LeadersSection extends StatelessWidget {
  const LeadersSection({super.key, required this.leads, required this.onLinkedIn, this.onOpenMember, this.onMessage});

  final List<ChapterPerson> leads;
  final ValueChanged<String> onLinkedIn;
  final ValueChanged<String>? onOpenMember;
  final ValueChanged<String>? onMessage;

  @override
  Widget build(BuildContext context) {
    if (leads.isEmpty) return const SectionEmpty('The committee has not been announced yet.');
    return Column(
      children: [
        for (final p in leads)
          PersonRow(
            person: p,
            onLinkedIn: p.linkedinUrl == null ? null : () => onLinkedIn(p.linkedinUrl!),
            onOpen: onOpenMember == null ? null : () => onOpenMember!(p.id),
            onMessage: onMessage == null ? null : () => onMessage!(p.id),
          ),
      ],
    );
  }
}

/// The roster: search, the three filters, the rows and "Show more members".
class MembersSection extends StatefulWidget {
  const MembersSection({super.key, this.onOpenMember});

  /// A member's row opens their profile (the shell's callback); not tappable without one.
  final ValueChanged<String>? onOpenMember;

  @override
  State<MembersSection> createState() => _MembersSectionState();
}

class _MembersSectionState extends State<MembersSection> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _changed(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) context.read<ChapterController>().setMemberSearch(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = context.watch<ChapterController>();
    final state = page.members;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CommunitySearchField(controller: _search, hint: 'Search members by name', onChanged: _changed),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 31,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: MemberFilter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final f = MemberFilter.values[i];
              final on = page.memberFilter == f;
              return GestureDetector(
                onTap: () => page.setMemberFilter(f),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: on ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(15.5),
                    border: Border.all(color: on ? AppColors.primary : AppColors.outlineVariant),
                  ),
                  child: Text(
                    f.label,
                    style: CommunityText.chip.copyWith(color: on ? Colors.white : AppColors.slate700),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        if (state.error != null)
          SectionFailed(message: state.error!, onRetry: page.retryMembers)
        else if (state.loading && state.items.isEmpty)
          const SectionLoading()
        else if (state.items.isEmpty)
          SectionEmpty(
            page.memberSearch.isNotEmpty || page.memberFilter != MemberFilter.all
                ? 'No members match.'
                : 'No members have joined yet.',
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
            child: Text(plural(page.memberTotal, 'member'), style: CommunityText.sectionCaption),
          ),
          for (final p in state.items)
            PersonRow(person: p, onOpen: widget.onOpenMember == null ? null : () => widget.onOpenMember!(p.id)),
          if (page.membersHasNext)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: CommunityButton(
                label: 'Show more members',
                outlined: true,
                expand: true,
                height: 36,
                busy: page.membersLoadingMore,
                onPressed: page.moreMembers,
              ),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Events, updates, resources
// ---------------------------------------------------------------------------

class EventsSection extends StatelessWidget {
  const EventsSection({super.key, required this.onOpenEvent, required this.onMessage});

  final ValueChanged<ChapterEvent> onOpenEvent;

  /// The API's refusal of an RSVP (an invite-only event) or of a cancel (a paid ticket), as a snackbar.
  final ValueChanged<String> onMessage;

  Future<void> _run(Future<String?> action) async {
    final message = await action;
    if (message != null) onMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    final page = context.watch<ChapterController>();
    final state = page.events;
    final past = page.pastEvents;
    final now = page.now;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _Tab(label: 'Upcoming', on: !past, onTap: () => page.loadEvents(past: false)),
              const SizedBox(width: 6),
              _Tab(label: 'Past', on: past, onTap: () => page.loadEvents(past: true)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SectionFailed(message: state.error!, onRetry: () => page.loadEvents()),
          )
        else if (state.loading && state.items.isEmpty)
          const SectionLoading()
        else if (state.items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SectionEmpty(
              past ? 'No past events yet.' : 'No upcoming events. Check back soon for the next meetup.',
            ),
          )
        else
          for (final (i, e) in state.items.indexed) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: CommunityColors.tileRule),
            MeetupRow(
              event: e,
              showChapter: false,
              past: past,
              onTap: () => onOpenEvent(e),
              footer: past
                  ? null
                  : MeetupRsvpBar(
                      event: e,
                      now: now,
                      busy: page.isEventBusy(e),
                      onRsvp: () => _run(page.rsvp(e)),
                      onCancel: () => _run(page.cancelRsvp(e)),
                      onTicket: () => onOpenEvent(e),
                    ),
            ),
          ],
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 28,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: on ? CommunityColors.blue50 : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: CommunityText.chip.copyWith(color: on ? CommunityColors.blue700 : AppColors.slate500),
          ),
        ),
      ),
    );
  }
}

class UpdatesSection extends StatelessWidget {
  const UpdatesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final page = context.watch<ChapterController>();
    final state = page.updates;
    if (state.error != null) return SectionFailed(message: state.error!, onRetry: page.retryUpdates);
    if (state.loading && state.items.isEmpty) return const SectionLoading();
    if (state.items.isEmpty) return const SectionEmpty('No updates from the committee yet.');
    return Column(
      children: [
        for (final u in state.items)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: CommunityCard(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              color: u.pinned ? CommunityColors.blue50 : Colors.white,
              borderColor: u.pinned ? const Color(0xFFBFDBFE) : CommunityColors.border,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (u.pinned) ...[
                        const Icon(LucideIcons.pin, size: 11, color: CommunityColors.blue700),
                        const SizedBox(width: 4),
                        Text('PINNED', style: CommunityText.pill.copyWith(color: CommunityColors.blue700)),
                        const SizedBox(width: 8),
                      ],
                      if (u.createdAt != null) Text(fullDate(u.createdAt!), style: CommunityText.meta),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(u.title, style: CommunityText.cardTitle),
                  const SizedBox(height: 4),
                  Text(u.body, style: CommunityText.body),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ResourcesSection extends StatelessWidget {
  const ResourcesSection({super.key, required this.onOpen});

  final ValueChanged<ChapterResource> onOpen;

  static Color tagColor(String tag) => switch (tag) {
    'PPTX' => const Color(0xFFB7472A),
    'PDF' => const Color(0xFFC0392B),
    'XLSX' => const Color(0xFF1D6F42),
    'MP4' => const Color(0xFF6B4EA8),
    _ => const Color(0xFF32629E),
  };

  @override
  Widget build(BuildContext context) {
    final page = context.watch<ChapterController>();
    final state = page.resources;
    if (state.error != null) return SectionFailed(message: state.error!, onRetry: page.retryResources);
    if (state.loading && state.items.isEmpty) return const SectionLoading();
    if (state.items.isEmpty) return const SectionEmpty('No decks, templates or recordings have been shared yet.');
    return Column(
      children: [
        for (final r in state.items)
          InkWell(
            onTap: () => onOpen(r),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: tagColor(r.tag), borderRadius: BorderRadius.circular(8)),
                    child: Text(r.tag, style: AppText.plexSans(9, FontWeight.w700, Colors.white, lineHeight: 11)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title, style: CommunityText.personName, maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text(
                          [r.kindLabel, if (r.sizeLabel != null) r.sizeLabel!].join(' · '),
                          style: CommunityText.personLine,
                        ),
                      ],
                    ),
                  ),
                  const Icon(LucideIcons.externalLink, size: 15, color: AppColors.slate400),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sponsors, nearby chapters
// ---------------------------------------------------------------------------

class SponsorsSection extends StatelessWidget {
  const SponsorsSection({super.key, required this.sponsors, required this.onOpen});

  final List<ChapterSponsor> sponsors;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in sponsors)
            GestureDetector(
              onTap: s.url == null ? null : () => onOpen(s.url!),
              child: Container(
                constraints: const BoxConstraints(minWidth: 104),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: CommunityColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (s.logo?.url != null)
                      SizedBox(
                        height: 28,
                        child: CachedNetworkImage(
                          imageUrl: s.logo!.url!,
                          fit: BoxFit.contain,
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    Text(s.name, style: CommunityText.metaStrong, textAlign: TextAlign.center),
                    if (s.tier != null) Text(s.tier!, style: CommunityText.meta),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NearbySection extends StatelessWidget {
  const NearbySection({super.key, required this.chapters, required this.onOpen});

  final List<ChapterSummary> chapters;
  final ValueChanged<ChapterSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chapters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = chapters[i];
          return SizedBox(
            width: 170,
            child: CommunityCard(
              padding: EdgeInsets.zero,
              onTap: () => onOpen(c),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ChapterCover(chapter: c, height: 48, tile: false),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: CommunityText.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(c.place, style: CommunityText.personLine, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(membersLabel(c.memberCount), style: CommunityText.meta),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
