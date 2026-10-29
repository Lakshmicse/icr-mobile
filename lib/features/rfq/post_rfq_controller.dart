import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'rfq_format.dart';
import 'rfq_links.dart' show PickedRfqFile, RfqClock;
import 'rfq_models.dart';
import 'rfq_repository.dart';
import 'rfq_rules.dart';

/// The supplier a quote request goes to, from a supplier's page.
class QuoteTarget {
  const QuoteTarget({required this.vendorId, this.companyId, this.supplierName, this.categoryKey, this.item});

  final String vendorId;

  /// Kept for the caller; the API needs only the listing.
  final String? companyId;
  final String? supplierName;

  /// The service's taxonomy key, when the request came from one.
  final String? categoryKey;

  /// The product, as the request's one line item.
  final RfqItem? item;
}

/// A file on its way up: chosen, being sent, or refused (with the reason, and the file kept so it can be sent again).
class PendingUpload {
  PendingUpload(this.file, {this.error});

  final PickedRfqFile file;
  String? error;

  String get name => file.name;
}

/// Posting a requirement, editing one, or asking one supplier for a quote.
///
/// The full composer keeps one [RequirementDraft] for both kinds, so switching
/// between an enquiry and an RFQ keeps what was typed. A quote request is a
/// private enquiry that goes out at once ([QuoteRequestDraft]); when the API
/// asks for the sender's mobile (`PHONE_NEEDED`) the form asks for it and the
/// next send carries it. A refused send keeps every value and shows the API's
/// own sentence.
class PostRfqController extends ChangeNotifier {
  PostRfqController({
    required this.repository,
    this.target,
    this.editingId,
    this.copyFromId,
    RfqKind? initialKind,
    String? subject,
  }) {
    if (initialKind != null) draft.kind = initialKind;
    if (target != null) {
      quote.title = subject ?? target!.item?.name ?? '';
      quote.category = target!.categoryKey ?? '';
      quote.quantity = '${target!.item?.quantity ?? 1}';
    } else if (subject != null) {
      draft.title = subject;
      _titleEdited = true;
    }
  }

  final RfqRepository repository;
  final QuoteTarget? target;
  final String? editingId;

  bool _disposed = false;

  /// The pickers' lists load in the background, so a person who leaves the form meanwhile (the notice for an
  /// account with no company shows at once) must not have the answer land on a disposed controller.
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  final String? copyFromId;

  final RequirementDraft draft = RequirementDraft();
  final QuoteRequestDraft quote = QuoteRequestDraft();

  Poster? _poster;
  Requirement? _source;
  List<CategoryNode> _categories = const [];
  List<CategoryNode> _specialisations = const [];
  bool _loading = false;
  String? _loadError;
  bool _sending = false;
  String? _error;
  Map<String, String> _problems = const {};
  bool _askPhone = false;
  bool _titleEdited = false;
  bool _started = false;

  /// The service taxonomy is on its way (true from the start until the first answer or refusal), so the picker says
  /// "loading" rather than "could not load" while it waits.
  bool _categoriesLoading = true;
  PostResult? _result;
  final List<PendingUpload> _uploads = [];
  int _uploading = 0;
  String? _uploadNotice;

  Poster? get poster => _poster;

  /// The requirement being edited or copied.
  Requirement? get source => _source;
  List<CategoryNode> get categories => _categories;
  List<CategoryNode> get specialisations => _specialisations;
  bool get loading => _loading;
  String? get loadError => _loadError;
  bool get sending => _sending;

  /// The API's refusal of the last send.
  String? get error => _error;
  Map<String, String> get problems => _problems;
  bool get askPhone => _askPhone;
  bool get started => _started;
  PostResult? get result => _result;

  /// Files still going up, or refused and waiting for a retry or a dismissal.
  List<PendingUpload> get uploads => List.unmodifiable(_uploads);

  /// A file is being sent: the post waits for it (a post sent mid-upload goes without the file).
  bool get uploading => _uploading > 0;

  /// Why the last files chosen were not all taken (a wrong type, too big, too many).
  String? get uploadNotice => _uploadNotice;

  bool get direct => target != null;
  bool get editing => editingId != null;

  /// The service list is still being fetched.
  bool get categoriesLoading => _categoriesLoading;

  /// A member of a company whose role does not post or run requirements (an office admin, a recruiter, a hiring
  /// manager): the API would refuse the post with "Insufficient role permissions", so the form says so first.
  bool get roleCannotPost => _poster?.roleCannotPost ?? false;

  /// What to tell that account ([roleCannotPost]).
  String get roleCannotPostMessage => roleCannotPost ? _poster!.cannotPostMessage : '';

  /// A requirement is posted for a company: someone acting as themselves registers or switches to one first
  /// (ICR staff post for ICR). The API refuses the post with its own sentence; this says so before the form.
  /// Editing a requirement one already owns is not held to it.
  bool get mustRegisterCompany {
    final p = _poster;
    return !direct && !editing && p != null && p.companyId == null && p.role != 'SUPER_ADMIN';
  }

  /// The company the requirement will belong to, named once at the top.
  String? get companyFromAccount => _poster?.companyId == null ? null : _poster?.companyName;

  /// ICR staff post with no company of their own, and so name one.
  bool get askCompany => _poster != null && _poster!.companyId == null && !editing && _poster!.role == 'SUPER_ADMIN';

  /// Whether the title follows the suggestion ([suggestedTitle]) or what was typed.
  bool get titleEdited => _titleEdited;

  Future<void> start() async {
    _started = true;
    _loading = true;
    try {
      final poster = await repository.me();
      _poster = poster;
      if (!direct) {
        final id = editingId ?? copyFromId;
        if (id != null) {
          final r = await repository.requirement(id);
          _source = r;
          final copy = RequirementDraft.from(r, copy: editingId == null);
          _adopt(copy);
          _titleEdited = editingId != null;
        } else {
          draft.contactName = poster.name;
          draft.email = poster.email;
          draft.contactPhone = poster.phone ?? '';
          draft.companyName = poster.companyName ?? '';
        }
        if (draft.email.isEmpty) draft.email = poster.email;
      }
      _askPhone = direct && !poster.hasPhone;
      _loadError = null;
    } catch (e) {
      _loadError = ApiError.from(e).message;
    } finally {
      _loading = false;
      notifyListeners();
    }
    // The pickers' lists, in the background.
    await _loadCategories();
    final sub = _subcategoryNode;
    if (sub != null) await _loadSpecialisations(sub.id);
  }

  Future<void> retry() async {
    _loadError = null;
    notifyListeners();
    await start();
  }

  void _adopt(RequirementDraft from) {
    draft
      ..kind = from.kind
      ..title = from.title
      ..companyName = from.companyName
      ..contactName = from.contactName.isEmpty ? (_poster?.name ?? '') : from.contactName
      ..contactPhone = from.contactPhone.isEmpty ? (_poster?.phone ?? '') : from.contactPhone
      ..email = from.email.isEmpty ? (_poster?.email ?? '') : from.email
      ..facilityType = from.facilityType
      ..places = from.places
      ..category = from.category
      ..subcategory = from.subcategory
      ..service = from.service
      ..text = from.text
      ..budget = from.budget
      ..items = from.items
      ..attachments = from.attachments
      ..audience = from.audience
      ..minYears = from.minYears
      ..minEmployees = from.minEmployees
      ..minAnnualTurnover = from.minAnnualTurnover
      ..minLast3YrTurnover = from.minLast3YrTurnover
      ..presence = from.presence
      ..compliance = from.compliance
      ..preQualEndDate = from.preQualEndDate
      ..dueDate = from.dueDate;
  }

  Future<void> _loadCategories() async {
    if (!_categoriesLoading) {
      _categoriesLoading = true;
      notifyListeners();
    }
    try {
      _categories = await repository.categories();
    } catch (_) {
      // The picker says the list could not load and offers to try again.
    } finally {
      _categoriesLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadCategories() => _loadCategories();

  Future<void> _loadSpecialisations(String parentId) async {
    try {
      _specialisations = await repository.specialisations(parentId);
    } catch (_) {
      _specialisations = const [];
    }
    notifyListeners();
  }

  // ---- The taxonomy, by key ----------------------------------------------------------

  CategoryNode? get _categoryNode => _categories.where((c) => c.key == draft.category).firstOrNull;

  CategoryNode? get _subcategoryNode => _categoryNode?.children.where((c) => c.key == draft.subcategory).firstOrNull;

  /// The sub-categories of the chosen category.
  List<CategoryNode> get subcategories => _categoryNode?.children ?? const [];

  /// A taxonomy key's name: from the tree, else the repository's, else the key in words.
  String nameOf(String key) {
    if (key.isEmpty) return '';
    for (final c in _categories) {
      if (c.key == key) return c.name;
      for (final s in c.children) {
        if (s.key == key) return s.name;
      }
    }
    for (final s in _specialisations) {
      if (s.key == key) return s.name;
    }
    return repository.categoryName(key) ?? prettyKey(key);
  }

  /// The most specific service chosen, as words.
  String get serviceLabel {
    final key = draft.service.isNotEmpty
        ? draft.service
        : (draft.subcategory.isNotEmpty ? draft.subcategory : draft.category);
    return nameOf(key);
  }

  /// "Category › Sub-category › Specialisation".
  String get servicePath =>
      [draft.category, draft.subcategory, draft.service].where((k) => k.isNotEmpty).map(nameOf).join(' › ');

  String get suggestedTitle => draft.suggestedTitle(serviceLabel: serviceLabel, company: companyFromAccount);

  /// The title that will be sent.
  String get effectiveTitle => _titleEdited && draft.title.trim().isNotEmpty ? draft.title : suggestedTitle;

  // ---- Editing the draft -------------------------------------------------------------------

  void update(void Function(RequirementDraft d) change) {
    change(draft);
    _revalidate();
    notifyListeners();
  }

  void updateQuote(void Function(QuoteRequestDraft q) change) {
    change(quote);
    _revalidate();
    notifyListeners();
  }

  void setTitle(String title) {
    draft.title = title;
    _titleEdited = title.trim().isNotEmpty;
    _revalidate();
    notifyListeners();
  }

  void setKind(RfqKind kind) {
    if (kind == draft.kind || editing) return;
    draft.kind = kind;
    // Inviting named suppliers is for an enquiry (a staged RFQ screens suppliers itself).
    if (kind == RfqKind.rfq) draft.audience = Audience.open;
    _problems = const {};
    notifyListeners();
  }

  // ---- Places ------------------------------------------------------------------------------

  /// Places matching what was typed: ICR's cities first, then the world.
  Future<List<RfqPlace>> searchPlaces(String query) => repository.searchPlaces(query);

  /// Whether another place may be added.
  bool get canAddPlace => draft.places.length < RfqLimits.maxLocations;

  /// Adds a place (once; a repeat of the same name is ignored). False when the list is full.
  bool addPlace(RfqPlace place) {
    if (place.label.trim().isEmpty) return false;
    if (draft.places.contains(place)) return true;
    if (!canAddPlace) return false;
    update((d) => d.places = [...d.places, place]);
    return true;
  }

  void removePlace(RfqPlace place) => update((d) => d.places = [...d.places]..remove(place));

  // ---- The service -------------------------------------------------------------------------

  void setCategory(String key) {
    if (key == draft.category) return;
    draft
      ..category = key
      ..subcategory = ''
      ..service = '';
    _specialisations = const [];
    _revalidate();
    notifyListeners();
  }

  Future<void> setSubcategory(String key) async {
    if (key == draft.subcategory) return;
    draft
      ..subcategory = key
      ..service = '';
    _specialisations = const [];
    _revalidate();
    notifyListeners();
    final node = _subcategoryNode;
    if (node != null) await _loadSpecialisations(node.id);
  }

  void setService(String key) => update((d) => d.service = key);

  // ---- Line items, audience, criteria ---------------------------------------------------------

  void addItem(RfqItem item) => update((d) => d.items = [...d.items, item]);

  void replaceItem(int index, RfqItem item) => update((d) => d.items = [...d.items]..[index] = item);

  void removeItem(int index) => update((d) => d.items = [...d.items]..removeAt(index));

  void setAudience(Audience audience) => update((d) => d.audience = audience);

  void toggleInvited(SupplierRef s) {
    final list = List.of(draft.invited);
    final i = list.indexWhere((x) => x.vendorId == s.vendorId);
    if (i >= 0) {
      list.removeAt(i);
    } else {
      list.add(s);
    }
    update((d) => d.invited = list);
  }

  void toggleCompliance(String key) {
    final set = {...draft.compliance};
    if (!set.remove(key)) set.add(key);
    update((d) => d.compliance = set);
  }

  // ---- Files -------------------------------------------------------------------------------

  /// Takes the files the person chose: each is checked (accepted type, ten megabytes at most, room left),
  /// then sent one at a time as a `rfq-attachment` upload and added with a title to start from. What was
  /// not taken is said in [uploadNotice]; a file the API refused stays in [uploads] with its sentence.
  Future<void> addFiles(List<PickedRfqFile> picked) async {
    if (picked.isEmpty) return;
    final problems = <String>[];
    final room = RfqLimits.maxAttachments - draft.attachments.length - _uploads.length;
    final accepted = <PendingUpload>[];
    for (final file in picked) {
      if (accepted.length >= room) {
        problems.add(
          room <= 0
              ? 'You have attached the most (${RfqLimits.maxAttachments}) files.'
              : 'Only $room more file${room == 1 ? '' : 's'} fit.',
        );
        break;
      }
      if (mimeTypeFor(file.name) == null) {
        problems.add('${file.name} is not a PDF, Office, text, zip or image file.');
      } else if (file.size > RfqLimits.maxUploadBytes) {
        problems.add('${file.name} is over 10 MB.');
      } else {
        accepted.add(PendingUpload(file));
      }
    }
    _uploadNotice = problems.isEmpty ? null : problems.join(' ');
    _uploads.addAll(accepted);
    notifyListeners();
    for (final upload in accepted) {
      await _send(upload);
    }
  }

  Future<void> retryUpload(PendingUpload upload) => _send(upload);

  void dismissUpload(PendingUpload upload) {
    _uploads.remove(upload);
    notifyListeners();
  }

  void dismissUploadNotice() {
    _uploadNotice = null;
    notifyListeners();
  }

  Future<void> _send(PendingUpload upload) async {
    upload.error = null;
    _uploading++;
    notifyListeners();
    try {
      final stored = await repository.uploadFile(upload.file, purpose: 'rfq-attachment');
      _uploads.remove(upload);
      draft.attachments = [...draft.attachments, stored];
    } catch (e) {
      upload.error = ApiError.from(e).message;
    } finally {
      _uploading--;
      _revalidate();
      notifyListeners();
    }
  }

  void setAttachmentTitle(int index, String title) {
    update((d) => d.attachments = [...d.attachments]..[index] = _retitled(d.attachments[index], title));
  }

  RfqFile _retitled(RfqFile f, String title) => RfqFile(
    id: f.id,
    title: title.length > RfqLimits.attachmentTitle ? title.substring(0, RfqLimits.attachmentTitle) : title,
    url: f.url,
    name: f.name,
    mimeType: f.mimeType,
    size: f.size,
  );

  void removeAttachment(int index) => update((d) => d.attachments = [...d.attachments]..removeAt(index));

  /// The files differ from what the requirement has stored: an edit then sends the whole list.
  bool get attachmentsChanged {
    final stored = _source?.files ?? const <RfqFile>[];
    final now = draft.attachments;
    if (stored.length != now.length) return true;
    for (var i = 0; i < now.length; i++) {
      if (stored[i].url != now[i].url || stored[i].title.trim() != now[i].title.trim()) return true;
    }
    return false;
  }

  // ---- Checking and sending -----------------------------------------------------------------

  /// Once a send has said what is wrong, the list follows what is typed.
  void _revalidate() {
    if (_problems.isEmpty) return;
    _problems = direct ? _quoteProblems() : _draftProblems(goingLive: _lastGoingLive);
  }

  bool _lastGoingLive = true;

  Map<String, String> _draftProblems({required bool goingLive}) =>
      // On the clock the date picker uses (RfqClock), so a day the picker offered is never already past.
      draft.problems(
        goingLive: goingLive,
        askCompany: askCompany,
        effectiveTitle: effectiveTitle,
        editing: editing,
        now: RfqClock.now(),
      );

  Map<String, String> _quoteProblems() => quote.problems(hasItem: target?.item != null, askPhone: _askPhone);

  /// Checks the form as a send would, without sending; true when it is ready.
  bool review({required bool publish}) {
    _lastGoingLive = publish;
    _problems = direct ? _quoteProblems() : _draftProblems(goingLive: publish);
    _error = null;
    notifyListeners();
    return _problems.isEmpty;
  }

  /// Sends it: a new requirement as a draft or live, an edit, or a quote
  /// request. False when the form has problems or the API refused; the values
  /// stay as typed either way.
  Future<bool> submit({required bool publish}) async {
    if (_sending || uploading) return false;
    if (!review(publish: publish)) return false;
    _sending = true;
    _error = null;
    notifyListeners();
    try {
      if (direct) {
        final t = target!;
        _result = await repository.create(quote.toCreate(vendorId: t.vendorId, item: t.item, sendPhone: _askPhone));
      } else if (editing) {
        await repository.update(
          editingId!,
          draft.toUpdate(
            effectiveTitle: effectiveTitle,
            companyFromAccount: companyFromAccount,
            sendAttachments: attachmentsChanged,
          ),
        );
        final publishing = publish && _source?.status == RfqStatus.draft;
        if (publishing) await repository.act(editingId!, RfqAction.publish);
        _result = PostResult(
          id: editingId!,
          kind: draft.kind,
          status: publishing ? RfqStatus.published : (_source?.status ?? RfqStatus.draft),
        );
      } else {
        // Invite-only requirements go out at once: a draft would tell the
        // invited suppliers about something they cannot open.
        final invitesOnly = draft.audience == Audience.invited && !draft.isRfq;
        final status = publish || invitesOnly ? RfqStatus.published : RfqStatus.draft;
        _result = await repository.create(
          draft.toCreate(status: status, effectiveTitle: effectiveTitle, companyFromAccount: companyFromAccount),
        );
      }
      return true;
    } catch (e) {
      final message = ApiError.from(e).message;
      _error = message;
      if (direct && !_askPhone && isPhoneRefusal(message)) _askPhone = true;
      return false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  /// "Post another": a blank form after a post.
  void reset() {
    _result = null;
    _error = null;
    _problems = const {};
    _titleEdited = false;
    _uploads.clear();
    _uploadNotice = null;
    final poster = _poster;
    final kind = draft.kind;
    _adopt(RequirementDraft()..kind = kind);
    draft
      ..title = ''
      ..items = []
      ..invited = []
      ..attachments = []
      ..audience = Audience.open
      ..contactName = poster?.name ?? ''
      ..email = poster?.email ?? ''
      ..contactPhone = poster?.phone ?? ''
      ..companyName = poster?.companyName ?? '';
    notifyListeners();
  }

  // ---- Inviting at create -----------------------------------------------------------------

  Future<List<SupplierHit>> findSuppliers(String query) => repository.findSuppliers(query);
}
