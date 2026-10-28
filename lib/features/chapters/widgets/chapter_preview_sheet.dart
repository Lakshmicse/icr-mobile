import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../chapter_format.dart';
import '../chapter_models.dart';
import '../chapters_controller.dart';
import '../community_kit.dart';
import 'chapter_card.dart';
import 'chapter_cover.dart';
import 'chapter_sections.dart';
import 'meetup_row.dart';

/// The quick look at a chapter from the board ("Preview Chapter"): the website's preview dialog as a
/// bottom sheet. Its banner, numbers, overview, committee and next three events come from the chapter's
/// own page (`GET /chapters/:slug`), read when the sheet opens; Join and Leave act through the board's
/// controller, so the card behind it changes as the member's place does.
Future<void> showChapterPreview(
  BuildContext context, {
  required ChaptersController board,
  required ChapterSummary chapter,
  required ValueChanged<ChapterEvent> onOpenEvent,
  required VoidCallback onOpenChapter,
  required VoidCallback onShare,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheet) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.92),
      child: ChapterPreviewSheet(
        board: board,
        chapterId: chapter.id,
        slug: chapter.slug,
        onOpenEvent: (e) {
          Navigator.pop(sheet);
          onOpenEvent(e);
        },
        onOpenChapter: () {
          Navigator.pop(sheet);
          onOpenChapter();
        },
        onShare: onShare,
      ),
    ),
  );
}

class ChapterPreviewSheet extends StatefulWidget {
  const ChapterPreviewSheet({
    super.key,
    required this.board,
    required this.chapterId,
    required this.slug,
    required this.onOpenEvent,
    required this.onOpenChapter,
    required this.onShare,
  });

  final ChaptersController board;
  final String chapterId;
  final String slug;
  final ValueChanged<ChapterEvent> onOpenEvent;
  final VoidCallback onOpenChapter;
  final VoidCallback onShare;

  @override
  State<ChapterPreviewSheet> createState() => _ChapterPreviewSheetState();
}

class _ChapterPreviewSheetState extends State<ChapterPreviewSheet> {
  ChapterDetail? _detail;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await widget.board.repository.detail(widget.slug);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiError.from(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _run(Future<String?> action) async {
    final message = await action;
    if (message != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (detail == null) {
      if (_loading) return const CommunityLoading(height: 280);
      return CommunityNotice(
        icon: LucideIcons.cloudOff,
        title: "Couldn't load this chapter",
        body: _error ?? 'Something went wrong.',
        action: 'Try again',
        onAction: _read,
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
      );
    }
    return ListenableBuilder(
      listenable: widget.board,
      builder: (context, _) {
        // The board holds the member's place, which a Join here changes.
        final c = widget.board.find(widget.chapterId) ?? detail.chapter;
        final busy = widget.board.isBusy(c);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ChapterCover(
                      chapter: c,
                      height: 88,
                      pills: c.joined ? ChapterCoverPills(chapter: c) : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(child: Text(c.name, style: CommunityText.cardTitleLarge)),
                              const SizedBox(width: 6),
                              const Icon(LucideIcons.badgeCheck, size: 17, color: AppColors.primary),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(LucideIcons.mapPin, size: 12, color: AppColors.slate400),
                              const SizedBox(width: 4),
                              Expanded(child: Text(c.place, style: CommunityText.personLine)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              CommunityPill(
                                label: membersLabel(c.memberCount),
                                icon: LucideIcons.users,
                                fill: CommunityColors.greyPill,
                                style: CommunityText.sectionPill,
                                height: 22,
                              ),
                              if (c.upcomingEventCount > 0)
                                CommunityPill(
                                  label: eventsLabel(c.upcomingEventCount),
                                  fill: CommunityColors.blue50,
                                  style: CommunityText.sectionPill.copyWith(color: CommunityColors.blue700),
                                  height: 22,
                                ),
                              if (detail.foundedYear != null)
                                CommunityPill(
                                  label: establishedLabel(detail.foundedYear!),
                                  fill: CommunityColors.greyPill,
                                  style: CommunityText.sectionPill,
                                  height: 22,
                                ),
                            ],
                          ),
                          if (c.description != null) ...[
                            const SizedBox(height: 14),
                            Text('Overview', style: CommunityText.personName),
                            const SizedBox(height: 4),
                            Text(c.description!, style: CommunityText.body),
                          ],
                        ],
                      ),
                    ),
                    if (detail.leads.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const CommunitySectionHeading(title: 'Leadership'),
                      const SizedBox(height: 4),
                      for (final p in detail.leads.take(3)) PersonRow(person: p),
                    ],
                    const SizedBox(height: 10),
                    const CommunitySectionHeading(title: 'Upcoming events'),
                    const SizedBox(height: 2),
                    if (detail.upcomingEvents.isEmpty)
                      const SectionEmpty('Nothing scheduled yet. Check back soon.')
                    else
                      for (final (i, e) in detail.upcomingEvents.take(3).indexed) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            indent: 16,
                            endIndent: 16,
                            color: CommunityColors.tileRule,
                          ),
                        MeetupRow(event: e, showChapter: false, onTap: () => widget.onOpenEvent(e)),
                      ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: CommunityColors.tileRule),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
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
                              if (c.role != ChapterRole.lead)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: busy ? null : () => _run(widget.board.leave(c)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text('Leave', style: CommunityText.buttonQuiet),
                                  ),
                                ),
                            ],
                          )
                        : CommunityButton(
                            label: 'Join Chapter',
                            icon: LucideIcons.userPlus,
                            expand: true,
                            height: 36,
                            busy: busy,
                            onPressed: () => _run(widget.board.join(c)),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Share chapter',
                    child: InkWell(
                      onTap: widget.onShare,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: CommunityColors.border),
                        ),
                        child: const Icon(LucideIcons.share2, size: 15, color: AppColors.slate600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CommunityButton(
                    label: 'View full details',
                    icon: LucideIcons.arrowRight,
                    outlined: true,
                    height: 36,
                    onPressed: widget.onOpenChapter,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
