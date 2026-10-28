import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/title_bar.dart';
import '../feed/feed_models.dart' show FeedPicture;
import 'api_study_repository.dart';
import 'demo_study_repository.dart';
import 'formula_sheet.dart';
import 'knowledge_controller.dart';
import 'study_format.dart';
import 'study_repository.dart';
import 'study_styles.dart';
import 'widgets/study_notice.dart';
import '../notifications/notifications_screen.dart';

/// Knowledge Center: the calculations an FM works from. The formulas of every group are one list under their
/// group's heading (the website opens one group at a time), a search finds a formula by its name, expression,
/// note or worked numbers, and a formula opens in a sheet with the expression drawn as math.
///
/// The hub pushes this screen, so it builds its own controller and repository. [repository] is for tests.
class KnowledgeCenterScreen extends StatefulWidget {
  const KnowledgeCenterScreen({super.key, required this.onBack, this.repository});

  final VoidCallback onBack;
  final StudyRepository? repository;

  @override
  State<KnowledgeCenterScreen> createState() => _KnowledgeCenterScreenState();
}

class _KnowledgeCenterScreenState extends State<KnowledgeCenterScreen> {
  final _search = TextEditingController();
  late final KnowledgeController _formulas;

  @override
  void initState() {
    super.initState();
    final repository =
        widget.repository ??
        (AppConfig.demo ? DemoStudyRepository() : ApiStudyRepository(api: context.read<ApiClient>()));
    _formulas = KnowledgeController(repository)..start();
    _search.addListener(() => _formulas.setSearch(_search.text));
  }

  @override
  void dispose() {
    _search.dispose();
    _formulas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: _formulas,
            builder: (context, _) => Stack(
              children: [
                Positioned.fill(
                  top: TitleBar.height,
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _formulas.refresh,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _toolbar()),
                        ..._body(),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: TitleBar(
                    title: 'Knowledge Center',
                    onBack: widget.onBack,
                    unread: _formulas.unread,
                    onBell: () => openNotifications(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    final shelves = _formulas.shelves;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: IcrSearchField(
            controller: _search,
            hint: 'Search formulas...',
            height: 40,
            onSubmitted: _formulas.setSearch,
          ),
        ),
        if (shelves.length > 1) ...[
          const SizedBox(height: 8),
          ChipRow(
            padding: 12,
            height: 34,
            children: [
              IcrChip(
                key: const ValueKey('knowledge-chip-all'),
                label: 'All ${_formulas.totalFormulas}',
                tone: _formulas.shelfSlug == null ? ChipTone.primary : ChipTone.outlined,
                height: 34,
                onTap: () => _formulas.selectShelf(null),
              ),
              for (final s in shelves)
                IcrChip(
                  key: ValueKey('knowledge-chip-${s.topic.slug}'),
                  label: '${s.topic.title} ${s.cards.length}',
                  tone: _formulas.shelfSlug == s.topic.slug ? ChipTone.primary : ChipTone.outlined,
                  height: 34,
                  onTap: () => _formulas.selectShelf(s.topic.slug),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1, color: AppColors.blockRule),
      ],
    );
  }

  List<Widget> _body() {
    if (_formulas.loading && _formulas.shelves.isEmpty) {
      return [
        SliverList(
          delegate: SliverChildListDelegate([
            const SizedBox(height: 16),
            for (var i = 0; i < 7; i++) const _RowSkeleton(),
          ]),
        ),
      ];
    }
    if (_formulas.error != null && _formulas.shelves.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StudyNotice(
            icon: LucideIcons.cloudOff,
            title: "Couldn't load the formulas",
            body: _formulas.error!,
            action: 'Try again',
            onAction: _formulas.refresh,
          ),
        ),
      ];
    }
    final sections = _formulas.sections;
    if (_formulas.shelves.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: StudyNotice(
            icon: LucideIcons.sigma,
            title: 'No formulas yet',
            body: 'Formulas show up here as ICR publishes them.',
          ),
        ),
      ];
    }
    if (sections.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StudyNotice(
            icon: LucideIcons.searchX,
            title: 'No formula matches',
            body: 'Nothing matches "${_formulas.search}". Try other words, or clear the search.',
            action: 'Clear search',
            onAction: () {
              _search.clear();
              _formulas.clearSearch();
            },
          ),
        ),
      ];
    }

    // Every row the sheet can page through, in the order the list shows them.
    final entries = <FormulaEntry>[
      for (final s in sections)
        for (final r in s.rows) FormulaEntry(card: r.card, shelf: s.shelf.topic.title, number: r.number),
    ];
    final items = <Widget>[];
    var at = 0;
    for (final s in sections) {
      items.add(_ShelfHeading(shelf: s.shelf, shown: s.rows.length, narrowed: _formulas.narrowed));
      if (s.shelf.error != null) {
        items.add(_ShelfError(message: s.shelf.error!, onRetry: _formulas.refresh));
      }
      for (final r in s.rows) {
        final index = at++;
        items.add(
          _FormulaRow(
            number: r.number,
            name: r.card.front,
            category: r.card.category,
            onTap: () => showFormulaSheet(context, entries: entries, index: index),
          ),
        );
      }
    }
    return [
      SliverList(
        delegate: SliverChildListDelegate([
          if (_formulas.narrowed)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Text(
                'Showing ${formulasLabel(_formulas.matchCount)} of ${_formulas.totalFormulas}',
                key: const ValueKey('knowledge-showing'),
                style: StudyText.shelfCount,
              ),
            )
          else
            const SizedBox(height: 6),
          ...items,
          const SizedBox(height: 28),
        ]),
      ),
    ];
  }
}

/// A group's heading: its picture, its name and how many formulas it holds.
class _ShelfHeading extends StatelessWidget {
  const _ShelfHeading({required this.shelf, required this.shown, required this.narrowed});

  final FormulaShelf shelf;
  final int shown;
  final bool narrowed;

  @override
  Widget build(BuildContext context) {
    final total = shelf.cards.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 40, height: 40, child: _Thumb(picture: shelf.topic.cover)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    shelf.topic.title,
                    style: StudyText.shelfTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  narrowed && shown != total ? '${formulasLabel(shown)} of $total' : formulasLabel(total),
                  style: StudyText.shelfCount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.picture});

  final FeedPicture? picture;

  @override
  Widget build(BuildContext context) {
    final plate = ColoredBox(
      color: AppColors.chipEmphasis,
      child: Icon(LucideIcons.sigma, size: 20, color: AppColors.primary.withValues(alpha: 0.7)),
    );
    final p = picture;
    if (p?.asset != null) return Image.asset(p!.asset!, fit: BoxFit.cover);
    if (p?.url != null) {
      return CachedNetworkImage(
        imageUrl: p!.url!,
        fit: BoxFit.cover,
        placeholder: (_, _) => const ColoredBox(color: AppColors.chipEmphasis),
        errorWidget: (_, _, _) => plate,
      );
    }
    return plate;
  }
}

/// One formula in the list: its number, its name, a chevron. Name only, as the website's tile: an expression is a
/// line, and a list of them is not scannable; the sheet has the room.
class _FormulaRow extends StatelessWidget {
  const _FormulaRow({required this.number, required this.name, required this.category, required this.onTap});

  final int number;
  final String name;
  final String? category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Semantics(
        button: true,
        label: 'Open the formula $name',
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: StudyColors.border),
          ),
          child: InkWell(
            customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.chipEmphasis, borderRadius: BorderRadius.circular(10)),
                      child: Text(number.toString().padLeft(2, '0'), style: StudyText.formulaNumber),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: StudyText.formulaName, maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (category != null) Text(category!.toUpperCase(), style: StudyText.formulaPeek),
                        ],
                      ),
                    ),
                    const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.slate400),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShelfError extends StatelessWidget {
  const _ShelfError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        key: const ValueKey('knowledge-shelf-error'),
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          children: [
            Expanded(child: Text("Couldn't load this group. $message", style: StudyText.note)),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text('Try again', style: StudyText.noteLink),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.slate100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
        ),
      ),
    );
  }
}
