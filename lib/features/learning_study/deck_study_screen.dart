import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/links.dart';
import '../../core/widgets/chips.dart';
import 'open_course.dart';
import 'study_controller.dart';
import 'study_format.dart';
import 'study_models.dart';
import 'study_repository.dart';
import 'study_styles.dart';
import 'widgets/flip_card.dart';
import 'widgets/study_card_face.dart';
import 'widgets/study_notice.dart';

/// Studying a deck: the card front, a tap turns it over to the answer (a real flip), then "Got it" or "Still
/// learning", previous and next, shuffle, a category filter, a star that the API keeps, the progress, and at the
/// end a summary that offers another pass over the cards not yet known.
///
/// A full-screen route with no tab bar: it is a focused task, and the hub's bar would take a card's height.
/// [DeckStudyScreen.starred] studies the member's starred cards from every deck instead.
class DeckStudyScreen extends StatefulWidget {
  const DeckStudyScreen.deck({
    super.key,
    required this.repository,
    required StudyTopic this.deck,
    this.random,
    this.onOpenCourse,
  });

  const DeckStudyScreen.starred({super.key, required this.repository, this.random}) : deck = null, onOpenCourse = null;

  final StudyRepository repository;
  final StudyTopic? deck;

  /// For tests: a seeded shuffle.
  final math.Random? random;

  /// Opens the Assess your knowledge course a locked deck belongs with (its page in the app); the future completes
  /// when the member is back. Default: [openAssessCourse].
  final Future<void> Function(BuildContext context, StudyCourseRef course)? onOpenCourse;

  @override
  State<DeckStudyScreen> createState() => _DeckStudyScreenState();
}

class _DeckStudyScreenState extends State<DeckStudyScreen> with WidgetsBindingObserver {
  late final DeckStudyController _c = widget.deck != null
      ? DeckStudyController.deck(widget.repository, widget.deck!, random: widget.random)
      : DeckStudyController.starred(widget.repository, random: widget.random);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _c.load();
  }

  /// Back in front (the member paid for the course in the browser, or opened it elsewhere): a deck that was locked
  /// is asked for again, so it opens at once if its course did.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _c.lock != null) _c.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: StudyColors.page,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _c,
            builder: (context, _) => Column(
              children: [
                _StudyBar(
                  title: _c.title,
                  onBack: () => Navigator.of(context).maybePop(),
                  shuffled: _c.shuffled,
                  onShuffle: _c.loaded && _c.visible.isNotEmpty && !_c.finished ? _c.toggleShuffle : null,
                ),
                Expanded(child: _body(context)),
              ],
            ),
          ),
        ),
      ),
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
    if (_c.finished) return _Summary(controller: _c, onBack: () => Navigator.of(context).maybePop());
    return _StudyView(controller: _c, onStar: _star);
  }
}

/// 56 dp like the title bar, with a shuffle toggle where the bell would be.
class _StudyBar extends StatelessWidget {
  const _StudyBar({required this.title, required this.onBack, required this.shuffled, required this.onShuffle});

  final String title;
  final VoidCallback onBack;
  final bool shuffled;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: 'Back',
            excludeSemantics: true,
            child: InkResponse(
              key: const ValueKey('study-back'),
              onTap: onBack,
              radius: 24,
              child: const SizedBox(
                width: 48,
                height: 56,
                child: Icon(Symbols.arrow_back, size: 24, color: AppColors.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(title, style: AppText.barTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Semantics(
            button: true,
            toggled: shuffled,
            enabled: onShuffle != null,
            label: shuffled ? 'Restore the original order' : 'Shuffle the deck',
            excludeSemantics: true,
            child: InkResponse(
              key: const ValueKey('study-shuffle'),
              onTap: onShuffle,
              radius: 24,
              child: SizedBox(
                width: 48,
                height: 56,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: shuffled ? AppColors.primary : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Symbols.shuffle,
                      size: 22,
                      color: shuffled
                          ? Colors.white
                          : onShuffle == null
                          ? AppColors.slate300
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// The cards: chips, progress, the card, the verdict and the way on.
class _StudyView extends StatelessWidget {
  const _StudyView({required this.controller, required this.onStar});

  final DeckStudyController controller;
  final Future<void> Function(StudyCard card) onStar;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final card = c.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Filters(controller: c),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Semantics(
                label: 'Card ${c.position} of ${c.total}',
                excludeSemantics: true,
                child: Text(
                  '${c.position} of ${c.total}',
                  key: const ValueKey('study-position'),
                  style: StudyText.position,
                ),
              ),
              const Spacer(),
              if (c.knownCount + c.learningCount > 0)
                Text(
                  'Got it ${c.knownCount} · Still learning ${c.learningCount}',
                  key: const ValueKey('study-tally'),
                  style: StudyText.progressNote,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              key: const ValueKey('study-progress'),
              value: c.progress,
              minHeight: 4,
              backgroundColor: AppColors.slate200,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: card == null
                ? const SizedBox.shrink()
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 470),
                      child: GestureDetector(
                        // A swipe pages the deck; a tap on the card flips it.
                        onHorizontalDragEnd: (d) {
                          final v = d.primaryVelocity ?? 0;
                          if (v < -300) c.next();
                          if (v > 300) c.previous();
                        },
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          layoutBuilder: (current, previous) =>
                              Stack(fit: StackFit.expand, children: [...previous, ?current]),
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
                              ),
                              back: StudyCardFace(
                                card: card,
                                back: true,
                                starred: c.isStarred(card),
                                onStar: () => onStar(card),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        _Verdict(controller: c),
        _NavRow(controller: c),
      ],
    );
  }

  static String? _caption(DeckStudyController c, StudyCard card) {
    if (!c.isStarredSession) return card.category;
    return [card.topicTitle, card.category].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
  }
}

/// The category chips (and Starred), or the note that the pass is over the cards not yet known.
class _Filters extends StatelessWidget {
  const _Filters({required this.controller});

  final DeckStudyController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.restricted) {
      return Container(
        key: const ValueKey('study-restricted'),
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
        decoration: BoxDecoration(color: StudyColors.amberFill, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Studying the ${c.total} you have not got yet',
                style: StudyText.note.copyWith(color: StudyColors.amberInk, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              key: const ValueKey('study-show-all'),
              onPressed: c.showAll,
              style: TextButton.styleFrom(minimumSize: const Size(48, 44), foregroundColor: StudyColors.amberInk),
              child: Text('Whole deck', style: StudyText.noteLink.copyWith(color: StudyColors.amberInk)),
            ),
          ],
        ),
      );
    }
    final categories = c.categories;
    final starred = c.starredCount;
    if (categories.length < 2 && starred == 0) return const SizedBox.shrink();
    final all = c.category == null && !c.starredOnly;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ChipRow(
        padding: 16,
        height: 36,
        children: [
          IcrChip(
            key: const ValueKey('study-chip-all'),
            label: 'All ${c.allCards.length}',
            tone: all ? ChipTone.primary : ChipTone.outlined,
            height: 36,
            onTap: () => c.setCategory(null),
          ),
          if (starred > 0)
            IcrChip(
              key: const ValueKey('study-chip-starred'),
              label: 'Starred $starred',
              tone: c.starredOnly ? ChipTone.primary : ChipTone.outlined,
              icon: Symbols.star,
              iconColor: c.starredOnly ? Colors.white : StudyColors.star,
              iconSize: 16,
              height: 36,
              onTap: c.toggleStarredOnly,
            ),
          if (categories.length > 1)
            for (final cat in categories)
              IcrChip(
                key: ValueKey('study-chip-${cat.name}'),
                label: '${cat.name} ${cat.count}',
                tone: c.category == cat.name ? ChipTone.primary : ChipTone.outlined,
                height: 36,
                onTap: () => c.setCategory(cat.name),
              ),
        ],
      ),
    );
  }
}

/// "Still learning" and "Got it": the member's own marks, kept for the session.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.controller});

  final DeckStudyController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final card = c.current;
    final known = card != null && c.isKnown(card);
    final learning = card != null && c.isLearning(card);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: _VerdictButton(
              key: const ValueKey('study-still-learning'),
              label: 'Still learning',
              icon: Symbols.replay,
              selected: learning,
              fill: StudyColors.amberFill,
              ink: StudyColors.amberInk,
              onPressed: () => c.mark(known: false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _VerdictButton(
              key: const ValueKey('study-got-it'),
              label: 'Got it',
              icon: Symbols.check,
              selected: known,
              fill: StudyColors.greenFill,
              ink: StudyColors.greenInk,
              onPressed: () => c.mark(known: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerdictButton extends StatelessWidget {
  const _VerdictButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.fill,
    required this.ink,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color fill;
  final Color ink;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: selected ? fill : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? ink : StudyColors.border, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onTap: onPressed,
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, weight: 600, color: ink),
                const SizedBox(width: 8),
                Text(label, style: StudyText.verdict.copyWith(color: ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Previous, a hint, next (the last card's next finishes the pass).
class _NavRow extends StatelessWidget {
  const _NavRow({required this.controller});

  final DeckStudyController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          _RoundButton(
            key: const ValueKey('study-previous'),
            label: 'Previous card',
            icon: Symbols.arrow_back,
            enabled: !c.atFirst,
            onPressed: c.previous,
          ),
          Expanded(
            child: Text(
              c.flipped ? 'Did you get it?' : 'Tap the card to flip it',
              textAlign: TextAlign.center,
              style: StudyText.hint,
            ),
          ),
          _RoundButton(
            key: const ValueKey('study-next'),
            label: c.atLast ? 'Finish' : 'Next card',
            icon: c.atLast ? Symbols.check : Symbols.arrow_forward,
            enabled: true,
            solid: true,
            onPressed: c.next,
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.solid = false,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final bool solid;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fill = solid && enabled ? AppColors.primary : Colors.white;
    final ink = solid && enabled
        ? Colors.white
        : enabled
        ? AppColors.onSurface
        : AppColors.slate300;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: Material(
        color: fill,
        shape: CircleBorder(side: BorderSide(color: solid && enabled ? AppColors.primary : StudyColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onPressed : null,
          child: SizedBox(width: 52, height: 52, child: Icon(icon, size: 24, weight: 600, color: ink)),
        ),
      ),
    );
  }
}

/// The end of a pass.
class _Summary extends StatelessWidget {
  const _Summary({required this.controller, required this.onBack});

  final DeckStudyController controller;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final rest = c.toReview.length;
    final everyCard = c.total;
    final knowAll = rest == 0;
    return SingleChildScrollView(
      key: const ValueKey('study-summary'),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(color: StudyColors.greenFill, shape: BoxShape.circle),
                  child: const Icon(Symbols.check_circle, fill: 1, size: 44, color: StudyColors.greenInk),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                c.isStarredSession ? 'Starred cards done' : 'Deck complete',
                textAlign: TextAlign.center,
                style: StudyText.summaryTitle,
              ),
              const SizedBox(height: 6),
              Text(
                knowAll ? 'You know all ${cardsLabel(everyCard)}.' : 'You went through ${cardsLabel(everyCard)}.',
                key: const ValueKey('study-summary-lead'),
                textAlign: TextAlign.center,
                style: StudyText.summaryLead,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      key: const ValueKey('study-stat-known'),
                      value: c.knownCount,
                      label: 'Got it',
                      fill: StudyColors.greenFill,
                      ink: StudyColors.greenInk,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      key: const ValueKey('study-stat-learning'),
                      value: c.learningCount,
                      label: 'Still learning',
                      fill: StudyColors.amberFill,
                      ink: StudyColors.amberInk,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      key: const ValueKey('study-stat-unmarked'),
                      value: c.unmarkedCount,
                      label: 'Not marked',
                      fill: AppColors.slate100,
                      ink: AppColors.slate600,
                    ),
                  ),
                ],
              ),
              if (c.starredOnShow > 0) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Symbols.star, fill: 1, size: 18, color: StudyColors.star),
                    const SizedBox(width: 6),
                    Text(
                      '${c.starredOnShow} starred for another pass',
                      key: const ValueKey('study-summary-starred'),
                      style: StudyText.summaryLead,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 26),
              SizedBox(
                height: 50,
                child: FilledButton(
                  key: const ValueKey('study-summary-rest'),
                  onPressed: knowAll ? c.studyAgain : c.studyTheRest,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    knowAll
                        ? 'Study them again'
                        : (rest == 1 ? 'Study the 1 you have not got' : 'Study the $rest you have not got'),
                    style: AppText.button.copyWith(fontSize: 16),
                  ),
                ),
              ),
              if (!knowAll) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    key: const ValueKey('study-summary-again'),
                    onPressed: c.studyAgain,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurface,
                      side: const BorderSide(color: StudyColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Start over',
                      style: AppText.button.copyWith(fontSize: 16, color: AppColors.onSurface),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    key: const ValueKey('study-summary-last'),
                    onPressed: c.previous,
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    child: Text('Back to the last card', style: AppText.link.copyWith(fontSize: 14)),
                  ),
                  TextButton(
                    key: const ValueKey('study-summary-back'),
                    onPressed: onBack,
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    child: Text('All decks', style: AppText.link.copyWith(fontSize: 14)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.value, required this.label, required this.fill, required this.ink});

  final int value;
  final String label;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text('$value', style: StudyText.statValue.copyWith(color: ink)),
            const SizedBox(height: 2),
            Text(label, style: StudyText.statLabel.copyWith(color: ink)),
          ],
        ),
      ),
    );
  }
}
