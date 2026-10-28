import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'study_format.dart';
import 'study_models.dart';
import 'study_repository.dart';
import '../learning/notify_safely.dart';

/// One Knowledge Center group with its formulas, or the sentence that says why they did not load.
class FormulaShelf {
  const FormulaShelf({required this.topic, this.cards = const [], this.error});

  final StudyTopic topic;
  final List<StudyCard> cards;
  final String? error;
}

/// A group as the list draws it: its formulas that match the search, each with its place in the group (the number
/// on its row does not change when a search hides its neighbours).
class FormulaSection {
  const FormulaSection({required this.shelf, required this.rows});

  final FormulaShelf shelf;
  final List<({int number, StudyCard card})> rows;
}

/// The Knowledge Center's state. The website opens a group at a time; on a phone the formulas of every group are
/// one list under their group's heading, so the search finds a formula wherever it sits. The list call carries
/// no cards, so each group is read on its own (`GET /learning/resources/:slug`, public, never refused).
class KnowledgeController extends ChangeNotifier with NotifySafely {
  KnowledgeController(this.repository);

  final StudyRepository repository;

  List<FormulaShelf> _shelves = const [];
  String _search = '';
  String? _shelfSlug;
  bool _loading = false;
  String? _error;
  int _unread = 0;
  bool _started = false;
  int _generation = 0;

  bool get started => _started;
  bool get loading => _loading;

  /// Set when not even the list of groups could be read.
  String? get error => _error;
  int get unread => _unread;
  String get search => _search;
  bool get narrowed => _search.isNotEmpty;
  List<FormulaShelf> get shelves => _shelves;

  /// The group chosen with the chips, or null for all of them.
  String? get shelfSlug => _shelfSlug;
  int get totalFormulas => _shelves.fold(0, (sum, s) => sum + s.cards.length);

  /// Groups that did not load, so the screen can offer to try again.
  bool get hasFailures => _shelves.any((s) => s.error != null);

  /// The groups (one when a chip is on) with the formulas that match. A search drops a group with none; with no
  /// search a group that failed stays, with its sentence.
  List<FormulaSection> get sections {
    final terms = queryTerms(_search);
    final out = <FormulaSection>[];
    for (final shelf in _shelves) {
      if (_shelfSlug != null && shelf.topic.slug != _shelfSlug) continue;
      final rows = [
        for (final (i, card) in shelf.cards.indexed)
          if (cardMatches(card, terms)) (number: i + 1, card: card),
      ];
      if (terms.isNotEmpty && rows.isEmpty) continue;
      out.add(FormulaSection(shelf: shelf, rows: rows));
    }
    return out;
  }

  int get matchCount => sections.fold(0, (sum, s) => sum + s.rows.length);

  Future<void> start() async {
    _started = true;
    await Future.wait([_load(notify: false), _loadUnread()]);
  }

  Future<void> refresh() => _load(notify: true);

  Future<void> _load({required bool notify}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (notify) notifyListeners();
    try {
      final all = await repository.topics();
      final topics = all.where((t) => !t.isDeck).toList()
        ..sort((a, b) {
          final byOrder = a.sortOrder.compareTo(b.sortOrder);
          return byOrder != 0 ? byOrder : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      final shelves = await Future.wait([
        for (final t in topics)
          () async {
            try {
              final full = await repository.topic(t.slug);
              return FormulaShelf(topic: t, cards: full.cards);
            } catch (e) {
              return FormulaShelf(topic: t, error: ApiError.from(e).message);
            }
          }(),
      ]);
      if (generation != _generation) return;
      _shelves = shelves;
      if (_shelfSlug != null && !shelves.any((s) => s.topic.slug == _shelfSlug)) _shelfSlug = null;
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

  void setSearch(String query) {
    if (query.trim() == _search) return;
    _search = query.trim();
    notifyListeners();
  }

  void clearSearch() => setSearch('');

  /// A group chip; pressing the one that is on goes back to all of them.
  void selectShelf(String? slug) {
    _shelfSlug = slug == _shelfSlug ? null : slug;
    notifyListeners();
  }

  Future<void> _loadUnread() async {
    try {
      _unread = await repository.unreadNotifications();
      notifyListeners();
    } catch (_) {}
  }
}
