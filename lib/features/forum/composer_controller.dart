import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import '../../core/config.dart';
import '../feed/feed_models.dart';
import '../feed/forum_json.dart';
import 'forum_file_picker.dart';
import 'forum_models.dart';
import 'forum_repository.dart';
import 'mentions/tag_person.dart' show matchPersonTag;
import 'rich_document.dart';

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
    ForumAttachment? initialAttachment,
    this.repostOfId,
  }) : _mode = mode,
       title = editing?.card.title ?? initialTitle ?? '',
       doc = editing != null
           ? RichDoc.fromHtml(editing.bodyHtml)
           : (initialBody == null ? RichDoc.empty : RichDoc.fromPlain(initialBody)),
       tags = [for (final t in editing?.card.tags ?? const <String>[]) t.startsWith('#') ? t.substring(1) : t],
       _topicKey = editing?.category?.key,
       _subKey = editing?.subcategory?.key,
       _attachment = editing?.attachment ?? initialAttachment {
    // The photos and videos a discussion already carries, so an edit keeps them and can take one off: the forum's
    // own photos, any picture an older build wrote into the body, then the body's videos.
    final photos = <String>[for (final id in editing?.imageIds ?? const <String>[]) '/uploads/$id'];
    for (final src in ForumJson.imageSources(editing?.bodyHtml ?? '')) {
      if (!photos.contains(src)) photos.add(src);
    }
    for (final src in [...photos, ...ForumJson.videoSources(editing?.bodyHtml ?? '')]) {
      final name = src.split('/').last;
      media.add(
        ForumMediaItem(
          attachment: ForumAttachment(uploadId: name, fileName: name, url: AppConfig.absoluteUrl(src)),
          isVideo: isForumVideoName(name),
        ),
      );
    }
    _originalMedia = [for (final m in media) m.src];
    _originalHtml = doc.toHtml() + _mediaHtml;
    _originalTitle = title;
    _originalTags = [...tags];
  }

  final ForumRepository repository;

  /// The discussion being edited; null for a new one.
  final ForumThread? editing;

  /// The discussion a new post reposts (sent as `repostOfId`); null for an ordinary post.
  final String? repostOfId;

  ComposerMode _mode;
  String title;

  /// The details, as the editor holds them: words with bold, italic, headings, lists and links.
  RichDoc doc;
  String? _html;
  List<String> tags;
  final List<String> pollOptions = ['', ''];
  String? _topicKey;
  String? _subKey;
  ForumAttachment? _attachment;
  bool _attachmentChanged = false;

  /// The photos and videos in the body, in order (owner, 11 Nov 2026: several on one discussion).
  final List<ForumMediaItem> media = [];
  List<String> _originalMedia = const [];

  String get _mediaHtml => media.map((m) => m.html).join();

  late final String _originalHtml;
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

  /// The details as plain words, a line each: what the rules read.
  String get body => doc.plainText;

  /// The details as the forum's HTML (what is sent): each tagged member still in the words is a link to their
  /// profile.
  String get bodyHtml => _html ??= doc.withMentions(_mentions).toHtml() + _mediaHtml;

  List<Mention> _mentions = const [];

  /// The people picked with "@" whose "@Name" is still in the details (the screen's picker knows them). Taken before
  /// the next [bodyHtml]; changes nothing on screen by itself.
  void setMentions(List<Mention> mentions) {
    _mentions = mentions;
    _html = null;
  }

  /// The editor's document changed.
  void setDoc(RichDoc value) {
    doc = value;
    _html = null;
    _changed();
  }

  /// The details replaced by plain words (a draft restored, a test).
  void setBody(String value) => setDoc(RichDoc.fromPlain(value));

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

  /// Adds what was typed in the Tags field. A person's tag ("@divyacn", or two in one, "@bindhya-s @divyacn") is
  /// first matched to the member it means ([matchPersonTag]) and stored as their handle, which is what the forum
  /// notifies; anything else goes in as [addTags] adds it. A person nobody fits, or several do, is not added: the
  /// sentence says so, and `rest` is what stays in the field for the reader to fix or pick from the list.
  Future<({String? note, String rest})> addTypedTags(String raw) async {
    final plain = <String>[];
    final people = <String>[];
    final person = RegExp(r'#?@([A-Za-z0-9._-]+)');
    for (final part in raw.split(RegExp(r'[,\n]'))) {
      if (!part.contains('@')) {
        plain.add(part);
        continue;
      }
      for (final m in person.allMatches(part)) {
        final handle = m.group(1)!.replaceAll(RegExp(r'[-_.]+$'), '');
        if (handle.isNotEmpty && !people.contains(handle)) people.add(handle);
      }
      final words = part.replaceAll(person, ' ').trim();
      if (words.isNotEmpty) plain.add(words);
    }
    String? note = plain.isEmpty ? null : addTags(plain.join(','));
    final left = <String>[];
    final nobody = <String>[];
    final several = <String>[];
    for (final handle in people) {
      try {
        final match = await matchPersonTag(
          handle,
          byHandle: repository.memberIdByHandle,
          search: repository.mentionable,
        );
        if (match.tag != null) {
          note = addTags(match.tag!) ?? note;
        } else {
          left.add('@$handle');
          (match.several ? several : nobody).add('@$handle');
        }
      } catch (_) {
        left.add('@$handle');
        note = "Unable to check @$handle. Try again.";
      }
    }
    if (nobody.isNotEmpty) {
      note = 'No member found for ${nobody.join(', ')}. Pick the person from the list so they are notified.';
    } else if (several.isNotEmpty) {
      note = 'More than one member matches ${several.join(', ')}. Pick the person from the list.';
    }
    return (note: note, rest: left.join(' '));
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

  /// Sends each of [files] to the forum's upload and holds it as a photo or video of the body. Stops at the first
  /// refusal and returns its sentence; a file over the forum's cap is refused before it is sent.
  Future<String?> addMedia(List<ForumFile> files) async {
    if (files.isEmpty) return null;
    _uploading = true;
    _error = null;
    notifyListeners();
    try {
      for (final file in files) {
        final video = isForumVideoName(file.name);
        final cap = video ? forumVideoMaxBytes : forumImageMaxBytes;
        if (file.bytes.length > cap) {
          return '${file.name} is too large. A ${video ? 'video' : 'photo'} can be up to ${cap ~/ (1024 * 1024)} MB.';
        }
        if (!video && photoIds.length >= forumMaxPhotos) {
          return 'A post can carry up to $forumMaxPhotos photos.';
        }
        final uploaded = await repository.upload(file);
        media.add(ForumMediaItem(attachment: uploaded, isVideo: video, bytes: file.bytes));
        _html = null;
        _touched = true;
      }
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _uploading = false;
      notifyListeners();
    }
  }

  /// Takes the photo or video at [index] off the body.
  void removeMedia(int index) {
    if (index < 0 || index >= media.length) return;
    media.removeAt(index);
    _html = null;
    _changed();
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
      return 'Two options are the same. Make each option different.';
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
    if (doc.isBlank && !bodyOptional) return 'Add details to explain your post.';
    if (doc.plainLength > ForumLimits.bodyMax) return 'The details can be at most ${ForumLimits.bodyMax} characters.';
    return null;
  }

  String? get topicProblem => _topicKey == null ? 'Select a category.' : null;

  /// What is missing, in the order the form asks for it.
  List<String> get problems => [?topicProblem, ?titleProblem, ?pollProblem, ?bodyProblem];

  bool get canSend => problems.isEmpty && !_sending && !_uploading;

  /// Whether anything differs from what an edit started with.
  bool get changed {
    if (!isEdit) {
      return title.trim().isNotEmpty || !doc.isBlank || filledOptions.isNotEmpty || tags.isNotEmpty;
    }
    return title.trim() != _originalTitle ||
        bodyHtml != _originalHtml ||
        !listEquals([for (final m in media) m.src], _originalMedia) ||
        !listEquals(tags, _originalTags) ||
        _topicKey != editing!.category?.key ||
        _subKey != editing!.subcategory?.key ||
        _attachmentChanged;
  }

  /// Whether leaving would lose something the reader wrote.
  bool get hasUnsentWork => !_sending && changed;

  /// The details are as the post has them, so an edit that does not change them sends none and leaves the stored
  /// HTML exactly as it is (the website's editor can hold a quote or code this one reads as paragraphs).
  bool get bodyUnchanged => isEdit && bodyHtml == _originalHtml;

  /// The photos on the draft, as the forum names them (`imageIds`).
  List<String> get photoIds => [
    for (final m in media)
      if (!m.isVideo) m.attachment.uploadId,
  ];

  /// An edit that changed the photos (against what the forum holds, so a picture an older build wrote into the body
  /// moves to the forum's own list whenever the post is saved).
  bool get photosChanged => !isEdit || !listEquals(photoIds, editing!.imageIds);

  /// The post has formatting this editor cannot hold (quotes, code), which an edit of its words would flatten.
  bool get editLosesFormatting => isEdit && htmlHasFormattingEditorLoses(editing!.bodyHtml);

  /// An edit that did not touch the topic sends none: the forum re-checks a topic it is sent, and a sub-topic since
  /// retired would refuse an edit of the title alone.
  bool get topicChanged => !isEdit || _topicKey != editing!.category?.key || _subKey != editing!.subcategory?.key;

  ForumDraft get draft => ForumDraft(
    categoryKey: topicChanged ? _topicKey : null,
    subcategoryKey: _subKey,
    title: title,
    body: bodyUnchanged ? null : body,
    bodyHtml: bodyUnchanged ? null : bodyHtml,
    kind: kind,
    tags: tags,
    attachment: !isEdit || _attachmentChanged ? _attachment : null,
    imageIds: isEdit ? (photosChanged ? photoIds : null) : (photoIds.isEmpty ? null : photoIds),
    pollOptions: isPoll && !isEdit ? filledOptions : null,
    repostOfId: isEdit ? null : repostOfId,
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
