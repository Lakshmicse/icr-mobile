import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../feed/feed_models.dart';
import 'mention_person.dart';
import 'mention_text.dart';

export 'mention_person.dart';

/// The "@" picker behind one text field: it watches the field, and while the caret sits right after an "@" and the
/// letters typed since ([mentionQueryAt]) it asks [search] for people (after a short pause, so typing is not a
/// request per letter) and holds what came back; [pick] puts "@First Last " in place of what was typed and records the
/// person, so that on send [mentionsIn] gives the people still tagged in the words.
///
/// It closes when the caret moves off the query, on a second space, when the field loses focus, or on [dismiss].
class MentionController extends ChangeNotifier {
  MentionController({
    required this.search,
    this.debounce = const Duration(milliseconds: 250),
    this.maxResults = 8,
    Iterable<Mention> initial = const [],
  }) {
    _picked.addAll(initial);
  }

  /// Where people come from. May be replaced (a screen that gets its repository late).
  MentionSearch search;
  final Duration debounce;
  final int maxResults;

  TextEditingController? _text;
  FocusNode? _focus;
  MentionQuery? _query;
  int? _dismissedAt;
  List<MentionPerson> _results = const [];
  String? _resultsFor;
  bool _loading = false;
  bool _failed = false;
  Timer? _timer;
  int _ticket = 0;
  bool _disposed = false;
  final _picked = <Mention>[];

  /// What is being typed after an "@" now, or null.
  MentionQuery? get query => _query;

  /// Whether the picker is showing: a query is under the caret, the field has focus, and it was not dismissed.
  bool get open => _query != null && _dismissedAt != _query!.start && (_focus?.hasFocus ?? true);

  /// A search is under way (or waiting out the pause).
  bool get loading => _loading;

  /// The last search failed.
  bool get failed => _failed;

  /// Up to [maxResults] people for the query.
  List<MentionPerson> get results => _results;

  /// The query the results are for; null before any search came back.
  String? get resultsFor => _resultsFor;

  /// The people picked and not yet cleared (some may since have been deleted from the text: see [mentionsIn]).
  List<Mention> get picked => List.unmodifiable(_picked);

  /// Watches [text] (its words and its caret) and, when given, [focus].
  void attach(TextEditingController text, [FocusNode? focus]) {
    detach();
    _text = text..addListener(_check);
    _focus = focus?..addListener(_focusChanged);
    _check();
  }

  void detach() {
    _text?.removeListener(_check);
    _focus?.removeListener(_focusChanged);
    _text = null;
    _focus = null;
  }

  void _focusChanged() => _notify();

  void _check() {
    final text = _text;
    if (text == null) return;
    final selection = text.selection;
    final query = selection.isValid && selection.isCollapsed ? mentionQueryAt(text.text, selection.baseOffset) : null;
    // A dismissal holds while the same "@" is being typed after; any other "@", or none, forgets it.
    if (query == null || query.start != _dismissedAt) _dismissedAt = null;
    if (query == _query) return;
    final previous = _query;
    _query = query;
    if (query == null) {
      _stop();
      _results = const [];
      _resultsFor = null;
      _notify();
      return;
    }
    if (previous == null || previous.start != query.start) {
      _results = const [];
      _resultsFor = null;
    }
    if (_dismissedAt == query.start) {
      _stop();
    } else if (previous == null || previous.search != query.search || _resultsFor != query.search) {
      _schedule(query);
    }
    _notify();
  }

  void _stop() {
    _timer?.cancel();
    _ticket++;
    _loading = false;
  }

  void _schedule(MentionQuery query) {
    _timer?.cancel();
    final ticket = ++_ticket;
    _loading = true;
    _failed = false;
    _timer = Timer(debounce, () async {
      List<MentionPerson>? found;
      try {
        found = await search(query.search);
      } catch (_) {
        found = null;
      }
      if (_disposed || ticket != _ticket) return;
      _loading = false;
      _failed = found == null;
      _results = found == null ? const [] : found.take(maxResults).toList();
      _resultsFor = query.search;
      _notify();
    });
  }

  /// Puts "@Name " where the query was and remembers the person.
  void pick(MentionPerson person) {
    final text = _text;
    final query = _query;
    if (text == null || query == null) return;
    final selection = text.selection;
    final caret = selection.isValid ? selection.baseOffset : query.end;
    final done = insertMention(text.text, query, caret, person.name);
    final mention = Mention(id: person.id, name: person.name);
    if (!_picked.contains(mention)) _picked.add(mention);
    text.value = TextEditingValue(
      text: done.text,
      selection: TextSelection.collapsed(offset: done.caret),
    );
    _focus?.requestFocus();
  }

  /// Closes the picker for the "@" being typed (Escape); another "@" opens it again.
  void dismiss() {
    final query = _query;
    if (query == null || _dismissedAt == query.start) return;
    _dismissedAt = query.start;
    _stop();
    _notify();
  }

  /// Records people already tagged in words being edited (a reply's anchors), so a save keeps them.
  void seed(Iterable<Mention> mentions) {
    for (final m in mentions) {
      if (!_picked.contains(m)) _picked.add(m);
    }
  }

  /// The people picked whose "@Name" is still in [text]: what a send tags. Deleted or reworded mentions are not in it.
  List<Mention> mentionsIn(String text) => mentionsStillIn(text, _picked);

  /// Forgets everyone picked (after a send), and closes the picker.
  void reset() {
    _picked.clear();
    _dismissedAt = null;
    _query = null;
    _results = const [];
    _resultsFor = null;
    _stop();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    detach();
    super.dispose();
  }
}
