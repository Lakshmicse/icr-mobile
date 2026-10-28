import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/links.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/section_heading.dart';
import '../../core/widgets/title_bar.dart';
import 'api_study_repository.dart';
import 'deck_study_screen.dart';
import 'decks_controller.dart';
import 'demo_study_repository.dart';
import 'study_models.dart';
import 'study_repository.dart';
import 'study_styles.dart';
import 'widgets/deck_card.dart';
import 'widgets/study_notice.dart';
import '../notifications/notifications_screen.dart';

/// Flash Cards: the decks (the Resource Center's question shelves) as a grid, a search over them, and a deck opens
/// the study screen.
///
/// The hub pushes this screen, so it builds its own controller and repository: a pushed route does not inherit
/// the tab's providers. [repository] is for tests.
class FlashCardsScreen extends StatefulWidget {
  const FlashCardsScreen({super.key, required this.onBack, this.repository});

  final VoidCallback onBack;
  final StudyRepository? repository;

  @override
  State<FlashCardsScreen> createState() => _FlashCardsScreenState();
}

class _FlashCardsScreenState extends State<FlashCardsScreen> with WidgetsBindingObserver {
  final _search = TextEditingController();
  late final StudyRepository _repository;
  late final DecksController _decks;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        (AppConfig.demo ? DemoStudyRepository() : ApiStudyRepository(api: context.read<ApiClient>()));
    WidgetsBinding.instance.addObserver(this);
    _decks = DecksController(_repository)..start();
    // The grid narrows as the person types; the keyboard's search key and the clear button reach the same place.
    _search.addListener(() => _decks.setSearch(_search.text));
  }

  /// Back in front (the member paid for a course in the browser, or opened one meanwhile): the courses that are
  /// open are read again, so a deck that goes with one opens at once.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _decks.reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    _decks.dispose();
    super.dispose();
  }

  Future<void> _open(StudyTopic deck) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeckStudyScreen.deck(repository: _repository, deck: deck),
      ),
    );
    // Opening a deck takes one of the plan's places and starring changes the lists: read them again.
    if (mounted) _decks.reload();
  }

  Future<void> _openStarred() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => DeckStudyScreen.starred(repository: _repository)));
    if (mounted) _decks.reload();
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
            listenable: _decks,
            builder: (context, _) => Stack(
              children: [
                Positioned.fill(
                  top: TitleBar.height,
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _decks.refresh,
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
                    title: 'Flash Cards',
                    onBack: widget.onBack,
                    unread: _decks.unread,
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
    final starred = _decks.starred.length;
    final note = _decks.planNote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: IcrSearchField(
            controller: _search,
            hint: 'Search flash-card decks...',
            height: 40,
            onSubmitted: _decks.setSearch,
          ),
        ),
        if (starred > 0) ...[
          const SizedBox(height: 8),
          ChipRow(
            padding: 12,
            height: 32,
            children: [
              IcrChip(
                key: const ValueKey('study-starred-chip'),
                label: 'Study starred ($starred)',
                tone: ChipTone.outlined,
                icon: Symbols.star,
                iconColor: StudyColors.star,
                iconSize: 16,
                height: 32,
                onTap: _openStarred,
              ),
            ],
          ),
        ],
        if (note != null) ...[const SizedBox(height: 10), _PlanNote(text: note, onSeePlans: _seePlans)],
        const SizedBox(height: 12),
        const Hairline(color: AppColors.blockRule),
      ],
    );
  }

  void _seePlans() => openUrl(context, _repository.plansLink());

  List<Widget> _body() {
    if (_decks.loading && _decks.decks.isEmpty) {
      return [
        SliverList(
          delegate: SliverChildListDelegate([
            const SizedBox(height: 14),
            for (var i = 0; i < 3; i++) ...[
              const DeckGridRow(left: _DeckSkeleton(), right: _DeckSkeleton()),
              const SizedBox(height: DeckGridRow.rowGap),
            ],
          ]),
        ),
      ];
    }
    if (_decks.error != null && _decks.decks.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StudyNotice(
            icon: LucideIcons.cloudOff,
            title: "Couldn't load the decks",
            body: _decks.error!,
            action: 'Try again',
            onAction: _decks.refresh,
          ),
        ),
      ];
    }
    final visible = _decks.visible;
    if (visible.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StudyNotice(
            icon: LucideIcons.layers,
            title: _decks.narrowed ? 'No deck matches' : 'No flash-card decks yet',
            body: _decks.narrowed
                ? 'Nothing matches "${_decks.search}". Try other words, or clear the search.'
                : 'Decks show up here as ICR publishes them.',
            action: _decks.narrowed ? 'Clear search' : null,
            onAction: _decks.narrowed
                ? () {
                    _search.clear();
                    _decks.clearSearch();
                  }
                : null,
          ),
        ),
      ];
    }
    final children = <Widget>[const SizedBox(height: 14), SectionHeading(title: _heading(visible.length))];
    children.add(const SizedBox(height: 10));
    for (var i = 0; i < visible.length; i += 2) {
      if (i > 0) children.add(const SizedBox(height: DeckGridRow.rowGap));
      children.add(DeckGridRow(left: _card(visible[i]), right: i + 1 < visible.length ? _card(visible[i + 1]) : null));
    }
    children.add(const SizedBox(height: 28));
    return [SliverList(delegate: SliverChildListDelegate(children))];
  }

  String _heading(int shown) =>
      _decks.narrowed ? 'Showing $shown of ${_decks.decks.length} decks' : '${_decks.decks.length} decks';

  Widget _card(StudyTopic deck) =>
      DeckCard(deck: deck, state: _decks.stateOf(deck), starred: _decks.starredIn(deck), onTap: () => _open(deck));
}

/// The line over the grid: what the plan opens of the decks, and the way to the plans.
class _PlanNote extends StatelessWidget {
  const _PlanNote({required this.text, required this.onSeePlans});

  final String text;
  final VoidCallback onSeePlans;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        key: const ValueKey('study-plan-note'),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Symbols.workspace_premium, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: StudyText.note),
                  TextButton(
                    onPressed: onSeePlans,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 44),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    child: Text('See plans', style: StudyText.noteLink),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckSkeleton extends StatelessWidget {
  const _DeckSkeleton();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.78,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.slate100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
        ),
      ),
    );
  }
}
