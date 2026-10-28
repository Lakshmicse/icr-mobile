import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import '../chapters/community_kit.dart' show fileSizeLabel;
import 'library_models.dart';
import 'library_repository.dart';

/// The picker's "write your own" option, at the foot of all three category pickers. A marker, never
/// stored: what is saved is whatever is typed in its place.
const otherOption = 'Other (add your own)';

/// A file chosen and the name it will be saved under. Only the part before the extension is editable: the
/// extension is what the library classifies the file by and what a download opens with.
class UploadEntry {
  UploadEntry({required this.id, required this.file, required this.name});

  final int id;
  final PickedFile file;

  /// The editable part of the name.
  String name;

  String get extension {
    final dot = file.name.lastIndexOf('.');
    return dot <= 0 ? '' : file.name.substring(dot);
  }

  /// The name the file goes up under: the edited base and the extension, path separators swapped out.
  String get fileName {
    final typed = name.replaceAll(RegExp(r'[\\/]'), '-').trim();
    final base = typed.isEmpty ? _splitBase(file.name) : typed;
    return '$base$extension';
  }

  static String _splitBase(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot <= 0 ? fileName : fileName.substring(0, dot);
  }

  static String baseOf(String fileName) => _splitBase(fileName);
}

/// Share a document with the library, or add files to one that is the member's own.
///
/// The rules are the API's and the website's: a title (200 characters) and a category (60) to file it
/// under, then an optional sub-category and specialisation (80 each, each only under the one above), a
/// description (2,000), and one to ten files of at most 10 MB in the formats the library takes. The bytes
/// go up first, one file at a time (`POST /uploads?purpose=document-hub`), then the entry is filed
/// (`POST /documents`, or `POST /documents/:id/files` in append mode). A failed send keeps everything
/// typed, and a file that already went up is not sent again on the retry.
class UploadController extends ChangeNotifier {
  UploadController({
    required this.repository,
    this.target,
    List<TaxonomyNode> taxonomy = const [],
    List<String> usedCategories = const [],
  }) : _taxonomy = taxonomy,
       _used = usedCategories;

  final LibraryRepository repository;

  /// Set to add files to a document the member shared, instead of filing a new one.
  final LibraryDocument? target;

  List<TaxonomyNode> _taxonomy;
  List<String> _used;

  final List<UploadEntry> _entries = [];
  int _nextId = 0;
  String _title = '';
  String _description = '';
  String? _category;
  String _categoryOther = '';
  String? _sub;
  String _subOther = '';
  String? _spec;
  String _specOther = '';

  bool _busy = false;
  bool _disposed = false;
  bool _showErrors = false;
  String? _error;
  double _progress = 0;
  int _uploadingIndex = 0;
  LibraryDocument? _result;
  final Map<int, StoredFile> _stored = {};

  bool get appending => target != null;
  List<UploadEntry> get entries => List.unmodifiable(_entries);

  /// How many more files this document can take.
  int get room => LibraryLimits.maxFiles - (target?.fileCount ?? 0);
  int get totalBytes => _entries.fold(0, (n, e) => n + e.file.size);

  String get title => _title;
  String get description => _description;
  String? get category => _category;
  String get categoryOther => _categoryOther;
  String? get subcategory => _sub;
  String get subcategoryOther => _subOther;
  String? get specialization => _spec;
  String get specializationOther => _specOther;

  bool get busy => _busy;
  String? get error => _error;

  /// 0 to 1 across the whole batch, by bytes.
  double get progress => _progress;

  /// 1-based position of the file going up now (0 when none).
  int get uploadingIndex => _uploadingIndex;

  /// The document that was filed or added to (set by a successful [submit]).
  LibraryDocument? get result => _result;

  /// The taxonomy and the categories in use arrived (the form asks the API when it opens).
  void setOptions({List<TaxonomyNode>? taxonomy, List<String>? usedCategories}) {
    if (taxonomy != null) _taxonomy = taxonomy;
    if (usedCategories != null) _used = usedCategories;
    _notify();
  }

  // --- the pickers ------------------------------------------------------------

  /// The platform's level-1 labels, then what the library already uses that they do not cover, then
  /// "Other": the shared vocabulary first, the uploader's own words at the seam.
  List<String> get categoryOptions {
    final taxonomy = [for (final n in _taxonomy) n.label];
    final known = {for (final t in taxonomy) t.toLowerCase()};
    return [
      ...taxonomy,
      for (final c in _used)
        if (c.isNotEmpty && !known.contains(c.toLowerCase())) c,
      otherOption,
    ];
  }

  TaxonomyNode? get _categoryNode {
    for (final n in _taxonomy) {
      if (n.label == _category) return n;
    }
    return null;
  }

  TaxonomyNode? get _subNode {
    final parent = _categoryNode;
    if (parent == null) return null;
    for (final n in parent.children) {
      if (n.label == _sub) return n;
    }
    return null;
  }

  /// The sub-category choices: the chosen category's children, then "Other". Empty (the field is a plain
  /// text box) when the category is the uploader's own or has no children.
  List<String> get subcategoryOptions {
    final node = _categoryNode;
    if (node == null || node.children.isEmpty) return const [];
    return [for (final c in node.children) c.label, otherOption];
  }

  List<String> get specializationOptions {
    final node = _subNode;
    if (node == null || node.children.isEmpty) return const [];
    return [for (final c in node.children) c.label, otherOption];
  }

  // --- what gets sent -----------------------------------------------------------

  String get resolvedCategory => (_category == otherOption ? _categoryOther : (_category ?? '')).trim();

  String get resolvedSubcategory {
    if (resolvedCategory.isEmpty) return '';
    if (subcategoryOptions.isEmpty) return _subOther.trim();
    return (_sub == otherOption ? _subOther : (_sub ?? '')).trim();
  }

  String get resolvedSpecialization {
    if (resolvedSubcategory.isEmpty) return '';
    if (specializationOptions.isEmpty) return _specOther.trim();
    return (_spec == otherOption ? _specOther : (_spec ?? '')).trim();
  }

  // --- editing --------------------------------------------------------------------

  void setTitle(String v) {
    _title = v;
    _notify();
  }

  void setDescription(String v) {
    _description = v;
    _notify();
  }

  /// Choosing a category clears the levels below it: they described the old one.
  void setCategory(String? v) {
    _category = v;
    _categoryOther = '';
    _sub = null;
    _subOther = '';
    _spec = null;
    _specOther = '';
    _notify();
  }

  void setCategoryOther(String v) {
    _categoryOther = v;
    _notify();
  }

  void setSubcategory(String? v) {
    _sub = v;
    _subOther = '';
    _spec = null;
    _specOther = '';
    _notify();
  }

  void setSubcategoryOther(String v) {
    _subOther = v;
    _notify();
  }

  void setSpecialization(String? v) {
    _spec = v;
    _specOther = '';
    _notify();
  }

  void setSpecializationOther(String v) {
    _specOther = v;
    _notify();
  }

  /// Takes what the picker handed over, minus what cannot go. Returns the sentences for what it left
  /// (too large, over the limit, a format the library does not take); the rest is kept, never cleared.
  List<String> pick(List<PickedFile> chosen) {
    final rejected = <String>[];
    for (final f in chosen) {
      if (!_acceptedExtension(f.name)) {
        rejected.add('${f.name} is not a format the library takes');
        continue;
      }
      if (f.size > LibraryLimits.maxBytes) {
        rejected.add('${f.name} (${fileSizeLabel(f.size)}) is over the 10 MB limit');
        continue;
      }
      // The same name and size twice is the picker opened twice on the same file, not two files.
      if (_entries.any((e) => e.file.name == f.name && e.file.size == f.size)) continue;
      if (_entries.length >= room) {
        rejected.add(
          '${f.name}: ${appending ? 'this document has room for $room more' : 'a document holds up to ${LibraryLimits.maxFiles} files'}',
        );
        continue;
      }
      _entries.add(UploadEntry(id: _nextId++, file: f, name: UploadEntry.baseOf(f.name)));
    }
    // The title starts as the first file's name, extension off: "FM handover checklist.pdf" is a filename.
    if (!appending && _title.isEmpty && _entries.isNotEmpty) _title = _entries.first.name;
    _error = rejected.isEmpty ? null : 'Not added: ${rejected.join('; ')}.';
    _notify();
    return rejected;
  }

  static bool _acceptedExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return false;
    return LibraryLimits.extensions.contains(name.substring(dot + 1).toLowerCase());
  }

  void remove(int id) {
    _entries.removeWhere((e) => e.id == id);
    _stored.remove(id);
    _notify();
  }

  void rename(int id, String base) {
    for (final e in _entries) {
      if (e.id == id) e.name = base;
    }
    // A renamed file goes up again under its new name.
    _stored.remove(id);
    _notify();
  }

  // --- validation ---------------------------------------------------------------------

  /// What is wrong with the form, by field; shown once a send was tried.
  Map<String, String> get problems {
    final p = <String, String>{};
    if (_entries.isEmpty) p['files'] = 'Choose at least one file.';
    for (final e in _entries) {
      if (e.fileName.length > LibraryLimits.fileName) {
        p['files'] = '${e.fileName.substring(0, 24)}… has too long a name (255 characters at most).';
      }
    }
    if (!appending) {
      if (_title.trim().isEmpty) {
        p['title'] = 'Give the document a title.';
      } else if (_title.trim().length > LibraryLimits.title) {
        p['title'] = 'A title is at most ${LibraryLimits.title} characters.';
      }
      if (resolvedCategory.isEmpty) {
        p['category'] = _category == otherOption ? 'Type the category.' : 'Choose a category.';
      } else if (resolvedCategory.length > LibraryLimits.category) {
        p['category'] = 'A category is at most ${LibraryLimits.category} characters.';
      }
      if (resolvedSubcategory.length > LibraryLimits.subcategory) {
        p['subcategory'] = 'A sub-category is at most ${LibraryLimits.subcategory} characters.';
      }
      if (resolvedSpecialization.length > LibraryLimits.specialization) {
        p['specialization'] = 'A specialisation is at most ${LibraryLimits.specialization} characters.';
      }
      if (_description.trim().length > LibraryLimits.description) {
        p['description'] = 'A description is at most ${LibraryLimits.description} characters.';
      }
    }
    return p;
  }

  /// The problem to show under [field]: only once a send was tried.
  String? problemFor(String field) => _showErrors ? problems[field] : null;

  bool get canSubmit => !_busy && problems.isEmpty;

  // --- sending --------------------------------------------------------------------------

  /// Files the document (or adds the files). Null with [error] set when the API refuses or nothing could
  /// be sent; everything typed stays, and files that already went up are not sent again.
  Future<LibraryDocument?> submit() async {
    if (_busy) return null;
    _showErrors = true;
    if (problems.isNotEmpty) {
      _error = null;
      _notify();
      return null;
    }
    _busy = true;
    _error = null;
    _progress = 0;
    _uploadingIndex = 0;
    _notify();
    try {
      final total = totalBytes == 0 ? 1 : totalBytes;
      var done = 0;
      final stored = <StoredFile>[];
      for (final (i, e) in _entries.indexed) {
        _uploadingIndex = i + 1;
        final known = _stored[e.id];
        if (known != null) {
          stored.add(known);
          done += e.file.size;
          _progress = (done / total).clamp(0, 1).toDouble();
          _notify();
          continue;
        }
        final named = PickedFile(name: e.fileName, bytes: e.file.bytes, mimeType: e.file.mimeType);
        final file = await repository.upload(
          named,
          onProgress: (p) {
            _progress = ((done + e.file.size * p) / total).clamp(0, 1).toDouble();
            _notify();
          },
        );
        _stored[e.id] = file;
        stored.add(file);
        done += e.file.size;
      }
      _progress = 1;
      final doc = appending
          ? await repository.addFiles(target!.id, stored)
          : await repository.create(
              DocumentDraft(
                title: _title.trim(),
                description: _description.trim().isEmpty ? null : _description.trim(),
                category: resolvedCategory,
                subcategory: resolvedSubcategory.isEmpty ? null : resolvedSubcategory,
                specialization: resolvedSpecialization.isEmpty ? null : resolvedSpecialization,
              ),
              stored,
            );
      _result = doc;
      return doc;
    } catch (e) {
      _error = ApiError.from(e).message;
      return null;
    } finally {
      _busy = false;
      _uploadingIndex = 0;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
