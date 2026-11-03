import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/util/links.dart';
import '../shell/icr_bottom_nav.dart';
import '../shell/shell_page.dart';
import 'open_course.dart';
import 'study_controller.dart';
import 'study_models.dart';
import 'study_repository.dart';
import 'study_styles.dart';
import 'widgets/flip_card.dart';
import 'widgets/study_bar.dart';
import 'widgets/study_card_face.dart';
import 'widgets/study_chips.dart';
import 'widgets/study_notice.dart';
import 'widgets/study_player.dart';
import 'widgets/study_summary.dart';

/// Studying a deck, in one view (flashcards-study.png): the title bar with a search and a ⋮ menu, the category
/// chips, the card, the player bar under it, and "Still learning" / "Got it". A tap on the card or on its Flip
/// Card pill turns it over (a real flip) to the answer; the player plays through the pass by itself, shuffles,
/// and goes back and on; a star is kept by the API; at the end a summary offers another pass over the cards not
/// yet known. The ⋮ menu holds the Starred pass and the summary.
///
/// The bottom bar of the app stays under it, as the design draws it, with Learning lit. The card takes the room
/// the screen has, so the answer, its example and its source link show without scrolling on a phone.
/// [DeckStudyScreen.starred] studies the member's starred cards from every deck instead.
class DeckStudyScreen extends StatefulWidget {
  const DeckStudyScreen.deck({
    super.key,
    required this.repository,
    required StudyTopic this.deck,
    this.random,
    this.pacing,
    this.onOpenCourse,
  });

  const DeckStudyScreen.starred({super.key, required this.repository, this.random, this.pacing})
    : deck = null,
      onOpenCourse = null;

  final StudyRepository repository;
  final StudyTopic? deck;

  /// For tests: a seeded shuffle.
  final math.Random? random;

  /// For tests: how long auto-play stays on a question and on an answer. Default: [readingTime].
  final StudyPacing? pacing;

  /// Opens the Assess your knowledge course a locked deck belongs with (its page in the app); the future completes
  /// when the member is back. Default: [openAssessCourse].
  final Future<void> Function(BuildContext context, StudyCourseRef course)? onOpenCourse;

  @override
  State<DeckStudyScreen> createState() => _DeckStudyScreenState();
}

/// What the ⋮ menu offers.
enum _MenuAction { starred, summary }

class _DeckStudyScreenState extends State<DeckStudyScreen> with WidgetsBindingObserver {
  late final DeckStudyController _c = widget.deck != null
      ? DeckStudyController.deck(widget.repository, widget.deck!, random: widget.random, pacing: widget.pacing)
      : DeckStudyController.starred(widget.repository, random: widget.random, pacing: widget.pacing);

  final _search = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _c.load();
  }

  /// Back in front (the member paid for the course in the browser, or opened it elsewhere): a deck that was locked
  /// is asked for again, so it opens at once if its course did. Out of sight, auto-play stops.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _c.lock != null) _c.load();
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) _c.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    _c.dispose();
    super.dispose();
  }

  /// Opens the course this deck belongs with, then asks for the deck again: the course may be open now.
  Future<void> _openCourse(StudyCourseRef course) async {
    await (widget.onOpenCourse ?? openAssessCourse)(context, course);
    if (mounted) await _c.load();
  }

  Future<void> _star(StudyCard card) async {
    final message = await _c.toggleStar(card);
    if (message != null && mounted) showMessage(context, message);
  }

  void _closeSearch() {
    _search.clear();
    _c.setQuery('');
    setState(() => _searching = false);
  }

  void _clearSearch() {
    _search.clear();
    _c.setQuery('');
  }

  void _onMenu(_MenuAction action) {
    switch (action) {
      case _MenuAction.starred:
        _c.toggleStarredOnly();
      case _MenuAction.summary:
        _c.finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: ShellPage(
        tab: AppTab.learning,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            // The card's own scrolling (a long answer, many categories) must not hide the app's bottom bar.
            child: NotificationListener<ScrollNotification>(
              onNotification: (_) => true,
              child: ListenableBuilder(
                listenable: _c,
                builder: (context, _) => Column(
                  children: [
                    _bar(context),
                    Expanded(child: _body(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(BuildContext context) {
    final usable = _c.loaded && _c.allCards.isNotEmpty && _c.lock == null && _c.error == null;
    return StudyBar(
      title: _c.title,
      onBack: () => Navigator.of(context).maybePop(),
      search: usable ? _search : null,
      searching: _searching,
      searchHint: _c.isStarredSession ? 'Search the starred cards' : 'Search this deck',
      onSearch: () => setState(() => _searching = true),
      onCloseSearch: _closeSearch,
      onSearchChanged: _c.setQuery,
      menu: usable ? _menu() : null,
    );
  }

  Widget _menu() {
    final starred = _c.starredCount;
    return PopupMenuButton<_MenuAction>(
      key: const ValueKey('study-menu'),
      tooltip: 'More',
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      onSelected: _onMenu,
      itemBuilder: (_) => [
        if (!_c.isStarredSession)
          PopupMenuItem(
            key: const ValueKey('study-menu-starred'),
            value: _MenuAction.starred,
            enabled: starred > 0 || _c.starredOnly,
            child: Text(_c.starredOnly ? 'Back to all cards' : 'Study starred cards ($starred)'),
          ),
        PopupMenuItem(
          key: const ValueKey('study-menu-summary'),
          value: _MenuAction.summary,
          enabled: !_c.finished && _c.total > 0,
          child: const Text('Pass summary'),
        ),
      ],
      child: const StudyMenuGlyph(),
    );
  }

  Widget _body(BuildContext context) {
    if (_c.loading && !_c.loaded) {
      return const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6)));
    }
    final lock = _c.lock;
    final course = lock?.course;
    if (lock != null && course != null) {
      // A deck that belongs with an Assess your knowledge course opens with it: the plan while it has a place,
      // ICR credits or payment for a level, all on the course's own page.
      return StudyNotice(
        key: const ValueKey('deck-course-lock'),
        icon: Symbols.lock,
        tint: StudyColors.amberInk,
        title: 'Opens with “${course.title}”',
        body: lock.message,
        action: 'Open ${course.title}',
        onAction: () => _openCourse(course),
        secondary: 'All decks',
        onSecondary: () => Navigator.of(context).maybePop(),
      );
    }
    if (lock != null) {
      return StudyNotice(
        icon: Symbols.lock,
        tint: StudyColors.amberInk,
        title: "This deck isn't open on your plan",
        // The API's own sentence says which: sign in, no decks included, or all the plan's places used.
        body: lock.message,
        action: 'See plans',
        onAction: () => openUrl(context, widget.repository.plansLink(lock.pricingSlug)),
        secondary: 'All decks',
        onSecondary: () => Navigator.of(context).maybePop(),
      );
    }
    if (_c.error != null) {
      return StudyNotice(
        icon: LucideIcons.cloudOff,
        title: "Couldn't load the cards",
        body: _c.error!,
        action: 'Try again',
        onAction: _c.load,
      );
    }
    if (_c.allCards.isEmpty) {
      return StudyNotice(
        icon: _c.isStarredSession ? Symbols.star : LucideIcons.layers,
        title: _c.isStarredSession ? 'No starred cards yet' : 'No cards in this deck yet',
        body: _c.isStarredSession
            ? 'Tap the star on a card while you study and it is kept here for another pass.'
            : 'Cards show up here as ICR publishes them.',
        action: 'Back to decks',
        onAction: () => Navigator.of(context).maybePop(),
      );
    }
    if (_c.finished) return StudySummary(controller: _c, onBack: () => Navigator.of(context).maybePop());
    return _StudyView(controller: _c, typed: _search.text.trim(), onStar: _star, onClearSearch: _clearSearch);
  }
}

/// The cards: the categories, the card, the player and the marks, laid out to fit the screen without scrolling.
class _StudyView extends StatelessWidget {
  const _StudyView({required this.controller, required this.typed, required this.onStar, required this.onClearSearch});

  final DeckStudyController controller;

  /// What is typed in the search, as the member typed it.
  final String typed;
  final Future<void> Function(StudyCard card) onStar;
  final VoidCallback onClearSearch;

  /// Under the card: the gap, the player bar, the gap, the marks with their tally line, the bottom margin.
  static const _below = 12 + StudyPlayer.height + 10 + StudyVerdict.buttonHeight + StudyVerdict.tallyHeight + 8;

  /// The card is never shorter than its header and footer and a few lines (the screen scrolls instead), and never
  /// taller than a card reads well.
  static const _minCard = 210.0;
  static const _maxCard = 480.0;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final card = c.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Filters(controller: c, maxRows: _maxRows(MediaQuery.sizeOf(context).height)),
        Expanded(
          child: card == null
              ? StudyNotice(
                  icon: Symbols.search_off,
                  title: typed.isEmpty ? 'No cards to study' : 'No card matches “$typed”',
                  body: 'Try another word, or clear the search to study the whole pass.',
                  action: typed.isEmpty ? null : 'Clear search',
                  onAction: onClearSearch,
                )
              : LayoutBuilder(
                  builder: (context, box) {
                    final cardHeight = (box.maxHeight - _below).clamp(_minCard, _maxCard).toDouble();
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: cardHeight, child: _card(c, card)),
                              const SizedBox(height: 12),
                              StudyPlayer(
                                playing: c.playing,
                                shuffled: c.shuffled,
                                canShuffle: c.total > 1,
                                atFirst: c.atFirst,
                                atLast: c.atLast,
                                position: c.position,
                                total: c.total,
                                progress: c.progress,
                                onPlay: c.togglePlay,
                                onShuffle: c.toggleShuffle,
                                onPrevious: c.previous,
                                onNext: c.next,
                              ),
                              const SizedBox(height: 10),
                              StudyVerdict(
                                known: c.isKnown(card),
                                learning: c.isLearning(card),
                                knownCount: c.knownCount,
                                learningCount: c.learningCount,
                                onKnown: () => c.mark(known: true),
                                onLearning: () => c.mark(known: false),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// A taller phone shows more rows of chips before they scroll inside their own box.
  static int _maxRows(double height) => height >= 780
      ? 6
      : height >= 660
      ? 4
      : 3;

  Widget _card(DeckStudyController c, StudyCard card) {
    return GestureDetector(
      // A swipe pages the deck; a tap on the card flips it.
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -300) c.next();
        if (v > 300) c.previous();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey('card-${c.position}-${card.id}'),
          child: FlipCard(
            key: const ValueKey('study-flip'),
            showBack: c.flipped,
            onTap: c.flip,
            semanticLabel: c.flipped
                ? 'Answer: ${card.back}. Tap to flip back to the question.'
                : 'Question: ${card.front}. Tap to see the answer.',
            front: StudyCardFace(
              card: card,
              back: false,
              caption: _caption(c, card),
              starred: c.isStarred(card),
              onStar: () => onStar(card),
              onFlip: c.flip,
            ),
            back: StudyCardFace(
              card: card,
              back: true,
              starred: c.isStarred(card),
              onStar: () => onStar(card),
              onFlip: c.flip,
            ),
          ),
        ),
      ),
    );
  }

  static String? _caption(DeckStudyController c, StudyCard card) {
    if (!c.isStarredSession) return card.category;
    return [card.topicTitle, card.category].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
  }
}

/// The category chips, or the note that the pass is over some of the cards only (the ones not yet known, or the
/// starred ones), with the way back to the whole deck; nothing but a little air when the deck has one category.
class _Filters extends StatelessWidget {
  const _Filters({required this.controller, required this.maxRows});

  final DeckStudyController controller;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.restricted) {
      return _Note(
        key: const ValueKey('study-restricted'),
        text: 'Studying the ${c.total} you have not got yet',
        buttonKey: const ValueKey('study-show-all'),
        onShowAll: c.showAll,
      );
    }
    if (c.starredOnly) {
      return _Note(
        key: const ValueKey('study-starred-pass'),
        text: 'Studying your ${c.total} starred ${c.total == 1 ? 'card' : 'cards'}',
        buttonKey: const ValueKey('study-starred-off'),
        onShowAll: c.toggleStarredOnly,
      );
    }
    final categories = c.categories;
    if (categories.length < 2) return const SizedBox(height: 12);
    return Column(
      children: [
        StudyCategories(
          names: [for (final cat in categories) cat.name],
          selected: c.category,
          onSelect: c.setCategory,
          maxRows: maxRows,
        ),
        const SizedBox(height: 7),
      ],
    );
  }
}

/// "Studying the 3 you have not got yet" and its "Whole deck" button, in the amber of a pass in progress.
class _Note extends StatelessWidget {
  const _Note({super.key, required this.text, required this.buttonKey, required this.onShowAll});

  final String text;
  final Key buttonKey;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
      decoration: BoxDecoration(color: StudyColors.amberFill, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: StudyText.note.copyWith(color: StudyColors.amberInk, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            key: buttonKey,
            onPressed: onShowAll,
            style: TextButton.styleFrom(minimumSize: const Size(48, 44), foregroundColor: StudyColors.amberInk),
            child: Text('Whole deck', style: StudyText.noteLink.copyWith(color: StudyColors.amberInk)),
          ),
        ],
      ),
    );
  }
}
