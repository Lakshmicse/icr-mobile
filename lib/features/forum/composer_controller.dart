import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import '../feed/feed_models.dart';
import '../feed/forum_json.dart';
import 'forum_models.dart';
import 'forum_repository.dart';

/// What a new discussion is (the website's composer, 19 Oct 2026): a discussion, or a poll. An edit keeps its own
/// kind (an older post may be a question), so the choice exists only on a new post.
enum ComposerMode { discussion, poll }

/// A discussion being written, or changed: the fields, the rules the API's DTO holds them to (checked as the reader
/// types, so the button and the hints say what is missing before anything is sent), the file, and the send. A send
/// that fails keeps every field and says what the API said.
class ComposerController extends ChangeNotifier {
  ComposerController({
    required this.repository,
    this.editing,
    ComposerMode mode = ComposerMode.discussion,
    String? initialTitle,
    String? initialBody,
  }) : _mode = mode,
       title = editing?.card.title ?? initialTitle ?? '',
       body = editing == null ? (initialBody ?? '') : ForumJson.htmlToText(editing.bodyHtml),
      tags = [for (final t in editing?.card.tags ?? const <String>[]) t.startsWith('#') ? t.substring(1) : t],
      _topicKey = editing?.category?.key,
      _subKey = editing?.subcategory?.key,
      _attachment = editing?.attachment {
    _originalBody = body;
    _originalTitle = title;
    _originalTags = [...tags];
  }

  final ForumRepository repository;

  /// The discussion being edited; null for a new one.
  final ForumThread? editing;

  ComposerMode _mode;
  String title;
  String body;
  List<String> tags;
  final List<String> pollOptions = ['', ''];
  String? _topicKey;
  String? _subKey;
  ForumAttachment? _attachment;
  bool _attachmentChanged = false;

  late final String _originalBody;
  late final String _originalTitle;
  late final List<String> _originalTags;

  List<TaxonomyNode> _taxonomy = const [];
  bool _taxonomyLoading = false;
  String? _taxonomyError;
  ForumAccess _access = const ForumAccess();

  bool _uploading = false;
  bool _sending = false;
  String? _error;
  bool _touched = false;
  bool _attempted = false;
  bool _disposed = false;

  bool get isEdit => editing != null;
  ComposerMode get mode => _mode;

  /// A poll: a new post made one, or an edit of a discussion that carries one.
  bool get isPoll => isEdit ? editing!.card.poll != null : _mode == ComposerMode.poll;

  /// The kind the draft is sent as: a new post is a discussion (a poll is a discussion with options); an edit keeps
  /// its own.
  ThreadKind get kind => editing?.card.kind ?? ThreadKind.discussion;

  List<TaxonomyNode> get taxonomy => _taxonomy;
  bool get taxonomyLoading => _taxonomyLoading;
  String? get taxonomyError => _taxonomyError;
  ForumAccess get access => _access;
  ForumAttachment? get attachment => _attachment;
  bool get uploading => _uploading;
  bool get sending => _sending;
  String? get error => _error;

  /// The reader has typed or chosen something: hints about what is missing show from now on.
  bool get touched => _touched;

  /// The reader pressed Post: what is still missing is said at the foot of the form too.
  bool get attempted => _attempted;

  /// The details are optional on a poll (when it is posted, and when it is edited later), required otherwise.
  bool get bodyOptional => isPoll;

  TaxonomyNode? get topic => _find(_taxonomy, _topicKey);
  String? get topicKey => _topicKey;
  String? get topicName => topic?.name ?? editing?.category?.name;

  List<TaxonomyNode> get subtopics => topic?.children ?? const [];
  String? get subtopicKey => _subKey;
  TaxonomyNode? get subtopic => _find(subtopics, _subKey);
  String? get subtopicName =>
      subtopic?.name ?? (_subKey == editing?.subcategory?.key ? editing?.subcategory?.name : null);

  static TaxonomyNode? _find(List<TaxonomyNode> nodes, String? key) {
    if (key == null) return null;
    for (final n in nodes) {
      if (n.key == key) return n;
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  /// Reads the taxonomy (the topics the composer offers) and the reader's standing.
  Future<void> start() async {
    await Future.wait([readTaxonomy(), _readAccess()]);
  }

  Future<void> readTaxonomy() async {
    if (_taxonomyLoading) return;
    _taxonomyLoading = true;
    _taxonomyError = null;
    notifyListeners();
    try {
      _taxonomy = await repository.taxonomy();
    } catch (e) {
      _taxonomyError = ApiError.from(e).message;
    } finally {
      _taxonomyLoading = false;
      notifyListeners();
    }
  }

  Future<void> _readAccess() async {
    try {
      _access = await repository.access();
      notifyListeners();
    } catch (_) {
      // The notice about moderation is a nicety.
    }
  }

  /// A topic the page the composer was opened from is on, chosen once the taxonomy is read, when none is yet.
  void presetTopic(String? slug) {
    if (slug == null || _topicKey != null) return;
    for (final n in _taxonomy) {
      if (n.slug == slug) {
        _topicKey = n.key;
        notifyListeners();
        return;
      }
    }
  }

  // --- the fields ---------------------------------------------------------------------------------------------

  void _changed() {
    _touched = true;
    if (_error != null) _error = null;
    notifyListeners();
  }

  void setMode(ComposerMode mode) {
    if (isEdit || mode == _mode) return;
    _mode = mode;
    _changed();
  }

  void setTitle(String value) {
    title = value;
    _changed();
  }

  void setBody(String value) {
    body = value;
    _changed();
  }

  void setTopic(TaxonomyNode? node) {
    _topicKey = node?.key;
    _subKey = null;
    _changed();
  }

  void setSubtopic(TaxonomyNode? node) {
    _subKey = node?.key;
    _changed();
  }

  /// The forum's own rule for a tag (`normaliseTags`): lower case, spaces to dashes, 32 characters, no "#".
  static String normaliseTag(String raw) {
    final t = raw.trim().replaceFirst(RegExp(r'^#+'), '').toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    return t.length > ForumLimits.tagChars ? t.substring(0, ForumLimits.tagChars) : t;
  }

  /// Adds the tags in [raw] (comma separated is fine). Returns the sentence when nothing could be added.
  String? addTags(String raw) {
    var refused = false;
    for (final part in raw.split(RegExp(r'[,\n]'))) {
      final tag = normaliseTag(part);
      if (tag.isEmpty || tags.contains(tag)) continue;
      if (tags.length >= ForumLimits.tags) {
        refused = true;
        break;
      }
      tags = [...tags, tag];
    }
    _changed();
    return refused ? 'A discussion can have at most ${ForumLimits.tags} tags.' : null;
  }

  void removeTag(String tag) {
    tags = [
      for (final t in tags)
        if (t != tag) t,
    ];
    _changed();
  }

  void setPollOption(int index, String value) {
    pollOptions[index] = value;
    _changed();
  }

  void addPollOption() {
    if (pollOptions.length >= ForumLimits.pollMax) return;
    pollOptions.add('');
    _changed();
  }

  void removePollOption(int index) {
    if (pollOptions.length <= ForumLimits.pollMin) return;
    pollOptions.removeAt(index);
    _changed();
  }

  // --- the file -----------------------------------------------------------------------------------------------

  /// Sends [file] to the forum's upload and holds what came back as the discussion's file.
  Future<String?> attach(ForumFile file) async {
    _uploading = true;
    _error = null;
    notifyListeners();
    try {
      _attachment = await repository.upload(file);
      _attachmentChanged = true;
      _touched = true;
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _uploading = false;
      notifyListeners();
    }
  }

  /// Takes a file not yet sent off the draft. (A file a discussion already carries cannot be taken off: the forum has
  /// no way to clear it, so an edit can only replace it.)
  void removeAttachment() {
    if (isEdit && !_attachmentChanged) return;
    _attachment = isEdit ? editing!.attachment : null;
    _attachmentChanged = false;
    _changed();
  }

  bool get canRemoveAttachment => !isEdit || _attachmentChanged;

  // --- the rules ----------------------------------------------------------------------------------------------

  /// The poll's non-blank options, trimmed.
  List<String> get filledOptions => [
    for (final o in pollOptions)
      if (o.trim().isNotEmpty) o.trim(),
  ];

  /// Why the poll's options cannot be posted as they are, or null.
  String? get pollProblem {
    if (!isPoll || isEdit) return null;
    final filled = filledOptions;
    if (filled.length < ForumLimits.pollMin) return 'A poll needs at least ${ForumLimits.pollMin} options.';
    if (filled.map((o) => o.toLowerCase()).toSet().length != filled.length) {
      return 'Two options read the same: make each one different.';
    }
    return null;
  }

  String? get titleProblem {
    final t = title.trim();
    if (t.length < ForumLimits.titleMin) return 'The title needs at least ${ForumLimits.titleMin} characters.';
    if (t.length > ForumLimits.titleMax) return 'The title can be at most ${ForumLimits.titleMax} characters.';
    return null;
  }

  String? get bodyProblem {
    final t = body.trim();
    if (t.isEmpty && !bodyOptional) return 'Add some details so people know what you mean.';
    if (t.length > ForumLimits.bodyMax) return 'The details can be at most ${ForumLimits.bodyMax} characters.';
    return null;
  }

  String? get topicProblem => _topicKey == null ? 'Choose the topic this belongs to.' : null;

  /// What is missing, in the order the form asks for it.
  List<String> get problems => [?topicProblem, ?titleProblem, ?pollProblem, ?bodyProblem];

  bool get canSend => problems.isEmpty && !_sending && !_uploading;

  /// Whether anything differs from what an edit started with.
  bool get changed {
    if (!isEdit) {
      return title.trim().isNotEmpty || body.trim().isNotEmpty || filledOptions.isNotEmpty || tags.isNotEmpty;
    }
    return title.trim() != _originalTitle ||
        body.trim() != _originalBody.trim() ||
        !listEquals(tags, _originalTags) ||
        _topicKey != editing!.category?.key ||
        _subKey != editing!.subcategory?.key ||
        _attachmentChanged;
  }

  /// Whether leaving would lose something the reader wrote.
  bool get hasUnsentWork => !_sending && changed;

  /// The body is the stored one's words, so an edit that does not change them sends none and leaves the website
  /// editor's formatting alone.
  bool get bodyUnchanged => isEdit && body.trim() == _originalBody.trim();

  /// An edit that did not touch the topic sends none: the forum re-checks a topic it is sent, and a sub-topic since
  /// retired would refuse an edit of the title alone.
  bool get topicChanged => !isEdit || _topicKey != editing!.category?.key || _subKey != editing!.subcategory?.key;

  ForumDraft get draft => ForumDraft(
    categoryKey: topicChanged ? _topicKey : null,
    subcategoryKey: _subKey,
    title: title,
    body: bodyUnchanged ? null : body,
    kind: kind,
    tags: tags,
    attachment: !isEdit || _attachmentChanged ? _attachment : null,
    pollOptions: isPoll && !isEdit ? filledOptions : null,
  );

  /// Sends the draft. Returns what the forum stored, or null when it refused (see [error]) or the form is short of
  /// something (see [problems]); every field stays as typed.
  Future<ForumThread?> send() async {
    _touched = true;
    _attempted = true;
    if (!canSend) {
      notifyListeners();
      return null;
    }
    _sending = true;
    _error = null;
    notifyListeners();
    try {
      final saved = isEdit ? await repository.update(editing!.id, draft) : await repository.create(draft);
      return saved;
    } catch (e) {
      _error = ApiError.from(e).message;
      return null;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }
}
