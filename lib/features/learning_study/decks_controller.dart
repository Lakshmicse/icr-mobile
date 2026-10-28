import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'study_format.dart';
import 'study_models.dart';
import 'study_repository.dart';
import '../learning/notify_safely.dart';

/// The Flash Cards screen's state: the decks (the Resource Center's question shelves), a search over them, what the
/// plan opens of them, and how many cards the member has starred in each.
class DecksController extends ChangeNotifier with NotifySafely {
  DecksController(this.repository);

  final StudyRepository repository;

  List<StudyTopic> _decks = const [];
  DeckPlan? _plan;
  List<StudyCard> _starred = const [];
  String _search = '';
  bool _loading = false;
  String? _error;
  int _unread = 0;
  bool _started = false;
  int _generation = 0;

  bool get started => _started;
  bool get loading => _loading;
  String? get error => _error;
  int get unread => _unread;
  String get search => _search;
  bool get narrowed => _search.isNotEmpty;
  List<StudyTopic> get decks => _decks;
  DeckPlan? get plan => _plan;
  List<StudyCard> get starred => _starred;

  /// The decks that take a place of their own, and whether some belong with a course: what the line over the grid
  /// counts (a deck that belongs with a course takes no place).
  List<StudyTopic> get _alone => [
    for (final d in _decks)
      if (!d.linked) d,
  ];
  bool get _anyLinked => _decks.any((d) => d.linked);

  /// The line over the grid when the plan opens only some decks.
  String? get planNote => _plan?.noteFor(_alone, anyLinked: _anyLinked);

  /// The decks that match the search (title and description, as the website's shelf search does).
  List<StudyTopic> get visible {
    final terms = queryTerms(_search);
    if (terms.isEmpty) return _decks;
    return [
      for (final d in _decks)
        if (matchesTerms(terms, [d.title, d.description])) d,
    ];
  }

  DeckState stateOf(StudyTopic deck) => _plan?.stateFor(deck) ?? DeckState.open;

  /// How many of the member's starred cards sit on [deck].
  int starredIn(StudyTopic deck) => _starred.where((c) => c.topicId == deck.id).length;

  Future<void> start() async {
    _started = true;
    await Future.wait([_load(notify: false), _loadUnread()]);
  }

  Future<void> refresh() => _load(notify: true);

  /// [notify] is false for the first load: `start()` runs from `initState`, before the first build reads `loading`.
  Future<void> _load({required bool notify}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (notify) notifyListeners();
    try {
      final all = await repository.topics();
      final decks = all.where((t) => t.isDeck).toList()
        ..sort((a, b) {
          final byOrder = a.sortOrder.compareTo(b.sortOrder);
          return byOrder != 0 ? byOrder : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      // The plan and the stars are extras: a deck list that cannot read them is still a deck list.
      final plan = await repository.deckPlan();
      List<StudyCard> starred;
      try {
        starred = await repository.starredCards();
      } catch (_) {
        starred = const [];
      }
      if (generation != _generation) return;
      _decks = decks;
      _plan = plan;
      _starred = starred;
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

  /// Re-reads only what studying (or opening a course) changes: the places taken, the courses open, the stars,
  /// without the spinner. Called when a study screen is left, when the member comes back from a course's page and
  /// when the app returns to the front (the member paid in the browser meanwhile).
  Future<void> reload() async {
    try {
      final plan = await repository.deckPlan();
      final starred = await repository.starredCards();
      _plan = plan;
      _starred = starred;
      notifyListeners();
    } catch (_) {}
  }

  void setSearch(String query) {
    if (query.trim() == _search) return;
    _search = query.trim();
    notifyListeners();
  }

  void clearSearch() => setSearch('');

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      notifyListeners();
    } catch (_) {}
  }
}
