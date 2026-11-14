import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../chapters/community_kit.dart';
import '../../chapters/resource_download.dart' show ResourceDownloader;
import '../../chapters/widgets/chapter_sections.dart'
    show AboutSection, PersonRow, SectionEmpty, SectionFailed, SectionLoading;
import '../../chapters/widgets/meetup_row.dart' show MeetupRow;
import '../../chapters/widgets/resource_row.dart' show ResourceRow;
import '../council_controller.dart';
import '../council_models.dart';

// The sections of a council's page. The chapter's page is their twin, and they borrow its rows (a person, a
// meetup, a file) and its section frame; what differs is the words the website uses for a council and the
// controller they read.

/// "About this council" and the "Industries covered" under it.
class CouncilOverviewSection extends StatelessWidget {
  const CouncilOverviewSection({super.key, required this.blocks, required this.segments});

  final List<AboutBlock> blocks;
  final List<String> segments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (blocks.isEmpty)
          const SectionEmpty('Council details will be published shortly.')
        else
          AboutSection(blocks: blocks),
        if (segments.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Industries Covered', style: CommunityText.personName),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('The sectors and specialisations this council represents.', style: CommunityText.personLine),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in segments)
                  CommunityPill(
                    label: s,
                    fill: CommunityColors.greyPill,
                    style: CommunityText.chip.copyWith(fontSize: 10.5),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The chair and office-bearers: a person's row opens their profile, the message glyph a conversation, the link
/// glyph their LinkedIn.
class CouncilLeadershipSection extends StatelessWidget {
  const CouncilLeadershipSection({
    super.key,
    required this.leads,
    required this.onLinkedIn,
    this.onOpenMember,
    this.onMessage,
  });

  final List<CouncilPerson> leads;
  final ValueChanged<String> onLinkedIn;
  final ValueChanged<String>? onOpenMember;
  final ValueChanged<String>? onMessage;

  @override
  Widget build(BuildContext context) {
    if (leads.isEmpty) return const SectionEmpty('Council office-bearers will be announced shortly.');
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

/// Upcoming and Past sessions, each row opening the event's sheet.
class CouncilEventsSection extends StatelessWidget {
  const CouncilEventsSection({super.key, required this.onOpenEvent});

  final ValueChanged<CouncilEvent> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final page = context.watch<CouncilController>();
    final state = page.events;
    final past = page.pastEvents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _PeriodTab(label: 'Upcoming', on: !past, onTap: () => page.loadEvents(past: false)),
              const SizedBox(width: 6),
              _PeriodTab(label: 'Past', on: past, onTap: () => page.loadEvents(past: true)),
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
              past
                  ? 'No past events. Past sessions will appear here.'
                  : 'No upcoming events. Sessions are planned regularly. Check back soon.',
            ),
          )
        else
          for (final (i, e) in state.items.indexed) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: CommunityColors.tileRule),
            MeetupRow(event: e, showChapter: false, past: past, onTap: () => onOpenEvent(e)),
          ],
      ],
    );
  }
}

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({required this.label, required this.on, required this.onTap});

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

/// The roster: search, the three filters (all, corporate only, the leadership), the rows and "Show more members".
class CouncilMembersSection extends StatefulWidget {
  const CouncilMembersSection({super.key, this.onOpenMember});

  /// A row opens the member's profile (their user id); not tappable without one.
  final ValueChanged<String>? onOpenMember;

  @override
  State<CouncilMembersSection> createState() => _CouncilMembersSectionState();
}

class _CouncilMembersSectionState extends State<CouncilMembersSection> {
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
      if (mounted) context.read<CouncilController>().setMemberSearch(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = context.watch<CouncilController>();
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
              return Semantics(
                button: true,
                selected: on,
                child: GestureDetector(
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
                ? 'No members match. Try a different search or clear the filter.'
                : 'No members have joined yet.',
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
            child: Text(
              'Showing ${groupThousands(state.items.length)} of ${plural(page.memberTotal, 'member')}',
              style: CommunityText.sectionCaption,
            ),
          ),
          for (final p in state.items)
            PersonRow(person: p, onOpen: widget.onOpenMember == null ? null : () => widget.onOpenMember!(p.id)),
          if (page.membersHasNext)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: CommunityButton(
                label: 'View More',
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

/// The knowledge library: benchmarks, whitepapers, templates and recordings, each row with the website's Download.
class CouncilKnowledgeSection extends StatelessWidget {
  const CouncilKnowledgeSection({super.key, required this.downloader, required this.opener});

  /// Saves a resource's file to the phone. Tests give their own.
  final ResourceDownloader downloader;

  /// Hands a recording's web page to the browser, as the website's link does.
  final Future<void> Function(BuildContext context, Uri uri) opener;

  @override
  Widget build(BuildContext context) {
    final page = context.watch<CouncilController>();
    final state = page.resources;
    if (state.error != null) return SectionFailed(message: state.error!, onRetry: page.retryResources);
    if (state.loading && state.items.isEmpty) return const SectionLoading();
    if (state.items.isEmpty) {
      return const SectionEmpty("No resources yet. The council's shared assets will appear here.");
    }
    return Column(
      children: [
        for (final (i, r) in state.items.indexed) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: CommunityColors.tileRule),
          ResourceRow(resource: r, downloader: downloader, opener: opener),
        ],
      ],
    );
  }
}

/// The council's announcements, pinned first.
class CouncilUpdatesSection extends StatelessWidget {
  const CouncilUpdatesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final page = context.watch<CouncilController>();
    final state = page.updates;
    if (state.error != null) return SectionFailed(message: state.error!, onRetry: page.retryUpdates);
    if (state.loading && state.items.isEmpty) return const SectionLoading();
    if (state.items.isEmpty) return const SectionEmpty('No announcements yet. Council updates will appear here.');
    return Column(
      children: [
        for (final u in state.items)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: CommunityCard(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              color: u.pinned ? CommunityColors.blue50 : Colors.white,
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
