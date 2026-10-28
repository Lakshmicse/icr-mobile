import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'study_models.dart';
import 'study_repository.dart';
import '../learning/notify_safely.dart';

/// Studying one deck (or the member's starred cards from every deck): which card is showing and whether it is
/// turned over, the order, a category filter, what the member marked as known, and the stars, which are kept by
/// the API (taken at once, put back if it refuses).
///
/// Order is a list of indexes into the cards on show, so shuffling never copies or changes the cards, and a star
/// is keyed by the card's id, so it survives a shuffle and a filter. The "got it / still learning" marks are the
/// session's: they are not saved anywhere (the API has no place for them).
class DeckStudyController extends ChangeNotifier with NotifySafely {
  /// A deck: its cards come from `GET /learning/resources/:slug`.
  DeckStudyController.deck(this.repository, StudyTopic deck, {math.Random? random})
    : title = deck.title,
      _slug = deck.slug,
      _random = random ?? math.Random();

  /// The member's starred cards, from every deck.
  DeckStudyController.starred(this.repository, {math.Random? random})
    : title = 'Starred cards',
      _slug = null,
      _random = random ?? math.Random();

  final StudyRepository repository;
  final String title;
  final String? _slug;
  final math.Random _random;

  List<StudyCard> _all = const [];
  final Set<String> _stars = {};
  final Set<String> _known = {};
  final Set<String> _learning = {};

  String? _category;

  /// The ids that were starred when the Starred chip was pressed, not the live set: taking a star back while
  /// studying the starred cards leaves the card in the deck, as the website does.
  Set<String>? _starredOnly;

  /// Restricts the session to these ids ("study the ones I have not got").
  Set<String>? _only;
  bool _shuffled = false;
  List<int> _order = const [];
  int _pos = 0;
  bool _flipped = false;
  bool _finished = false;
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  DeckLocked? _lock;
  int _generation = 0;

  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  /// Set when the plan does not open the deck: the API's own sentence and the plans page.
  DeckLocked? get lock => _lock;
  bool get isStarredSession => _slug == null;
  List<StudyCard> get allCards => _all;
  bool get shuffled => _shuffled;
  bool get flipped => _flipped;
  bool get finished => _finished;
  String? get category => _category;
  bool get starredOnly => _starredOnly != null;
  bool get restricted => _only != null;

  /// The cards on show: the category, the Starred chip and the review restriction applied.
  List<StudyCard> get visible => [
    for (final c in _all)
      if ((_category == null || c.category == _category) &&
          (_starredOnly == null || _starredOnly!.contains(c.id)) &&
          (_only == null || _only!.contains(c.id)))
        c,
  ];

  int get total => _order.length;

  /// 1-based; 0 when nothing is on show.
  int get position => total == 0 ? 0 : _pos + 1;
  StudyCard? get current => total == 0 ? null : visible[_order[_pos]];
  bool get atFirst => _pos == 0;
  bool get atLast => total == 0 || _pos == total - 1;
  double get progress => total == 0 ? 0 : position / total;

  /// The categories of the whole deck in first-appearance order, with how many cards each holds.
  List<({String name, int count})> get categories {
    final counts = <String, int>{};
    for (final c in _all) {
      final name = c.category;
      if (name != null && name.isNotEmpty) counts[name] = (counts[name] ?? 0) + 1;
    }
    return [for (final e in counts.entries) (name: e.key, count: e.value)];
  }

  bool isStarred(StudyCard card) => _stars.contains(card.id);

  /// The deck's own cards the member has starred.
  int get starredCount => _all.where((c) => _stars.contains(c.id)).length;
  bool isKnown(StudyCard card) => _known.contains(card.id);
  bool isLearning(StudyCard card) => _learning.contains(card.id);

  // The summary at the end of a pass, over the cards that were on show.
  int get knownCount => visible.where((c) => _known.contains(c.id)).length;
  int get learningCount => visible.where((c) => _learning.contains(c.id)).length;
  int get unmarkedCount => total - knownCount - learningCount;
  int get starredOnShow => visible.where((c) => _stars.contains(c.id)).length;

  /// The ids of the cards on show that are not known: what "study the rest" goes over.
  List<StudyCard> get toReview => [
    for (final c in visible)
      if (!_known.contains(c.id)) c,
  ];

  Future<void> load() async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    _lock = null;
    notifyListeners();
    try {
      final slug = _slug;
      if (slug == null) {
        final cards = await repository.starredCards();
        if (generation != _generation) return;
        _all = cards;
        _stars
          ..clear()
          ..addAll(cards.map((c) => c.id));
      } else {
        final topic = await repository.topic(slug);
        if (generation != _generation) return;
        _all = topic.cards;
        try {
          final starred = await repository.starredCards();
          _stars
            ..clear()
            ..addAll(starred.map((c) => c.id));
        } catch (_) {
          // Without the star list the cards still study; they just show no stars.
        }
      }
      _loaded = true;
      _rebuild();
    } on DeckLocked catch (e) {
      if (generation != _generation) return;
      _lock = e;
    } catch (e) {
      if (generation != _generation) return;
      _error = ApiError.from(e).message;
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Lays the order out afresh over what is on show, back at the first card.
  void _rebuild() {
    _order = List<int>.generate(visible.length, (i) => i);
    if (_shuffled) _order.shuffle(_random);
    _pos = 0;
    _flipped = false;
    _finished = false;
  }

  void flip() {
    if (current == null || _finished) return;
    _flipped = !_flipped;
    notifyListeners();
  }

  void next() {
    if (current == null || _finished) return;
    if (_pos >= total - 1) {
      finish();
      return;
    }
    _pos++;
    _flipped = false;
    notifyListeners();
  }

  void previous() {
    if (current == null || _pos == 0) return;
    if (_finished) {
      _finished = false;
      notifyListeners();
      return;
    }
    _pos--;
    _flipped = false;
    notifyListeners();
  }

  /// Ends the pass: the summary.
  void finish() {
    if (_finished || total == 0) return;
    _finished = true;
    notifyListeners();
  }

  /// "Got it" ([known] true) or "Still learning", then the next card (the summary after the last).
  void mark({required bool known}) {
    final card = current;
    if (card == null || _finished) return;
    if (known) {
      _known.add(card.id);
      _learning.remove(card.id);
    } else {
      _learning.add(card.id);
      _known.remove(card.id);
    }
    if (_pos >= total - 1) {
      _finished = true;
      notifyListeners();
    } else {
      next();
    }
  }

  void toggleShuffle() {
    _shuffled = !_shuffled;
    _rebuild();
    notifyListeners();
  }

  /// A category chip (null is "All"): back to the first card of what is left.
  void setCategory(String? name) {
    _category = name == _category ? null : name;
    _starredOnly = null;
    _rebuild();
    notifyListeners();
  }

  /// The Starred chip: the cards starred right now, frozen for the pass.
  void toggleStarredOnly() {
    if (_starredOnly != null) {
      _starredOnly = null;
    } else {
      _category = null;
      _starredOnly = {..._stars.where((id) => _all.any((c) => c.id == id))};
    }
    _rebuild();
    notifyListeners();
  }

  /// Stars or unstars [card] at once; a sentence when the API refuses, after putting the star back as it was.
  Future<String?> toggleStar(StudyCard card) async {
    final wanted = !_stars.contains(card.id);
    wanted ? _stars.add(card.id) : _stars.remove(card.id);
    notifyListeners();
    try {
      await repository.setStar(card.id, wanted);
      return null;
    } catch (e) {
      wanted ? _stars.remove(card.id) : _stars.add(card.id);
      notifyListeners();
      return ApiError.from(e).message;
    }
  }

  /// Another pass over the whole of what was on show, from the first card, marks cleared.
  void studyAgain() {
    _known.clear();
    _learning.clear();
    _only = null;
    _rebuild();
    notifyListeners();
  }

  /// A pass over just the cards that were not marked "got it".
  void studyTheRest() {
    final rest = toReview.map((c) => c.id).toSet();
    if (rest.isEmpty) return;
    _only = rest;
    _rebuild();
    notifyListeners();
  }

  /// Leaves the review restriction (and the chips) for the whole deck.
  void showAll() {
    _only = null;
    _category = null;
    _starredOnly = null;
    _rebuild();
    notifyListeners();
  }
}
