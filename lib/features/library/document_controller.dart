import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'library_models.dart';
import 'library_repository.dart';

/// What reading one file came to: its bytes, or why not. A refusal that is the API
/// saying the plan does not open the document (a 403) is a [locked] one: the page draws it as the lock
/// card, in the server's own words, not as an error toast.
class FileOutcome {
  const FileOutcome.ok(DocumentBytes this.file) : error = null, locked = false;
  const FileOutcome.failed(String this.error, {this.locked = false}) : file = null;

  final DocumentBytes? file;
  final String? error;
  final bool locked;
}

/// One document's page: the document, who the member is (for "mine"), the actions on it, and the
/// server's lock message when the plan does not open it. A change a person makes (a view, a
/// file added or dropped) is told to the list behind the page through [onChanged] and [onRemoved].
class DocumentController extends ChangeNotifier {
  DocumentController({
    required this.repository,
    required this.documentId,
    LibraryDocument? initial,
    this.onChanged,
    this.onRemoved,
  }) : _doc = initial;

  final LibraryRepository repository;
  final String documentId;
  final ValueChanged<LibraryDocument>? onChanged;
  final ValueChanged<String>? onRemoved;

  LibraryDocument? _doc;
  LibraryViewer? _viewer;
  bool _started = false;
  bool _loading = false;
  bool _disposed = false;
  String? _error;
  String? _lock;
  bool _viewCounted = false;
  bool _reported = false;
  bool _removed = false;
  final Set<String> _busy = {};

  LibraryDocument? get document => _doc;
  LibraryViewer? get viewer => _viewer;
  bool get started => _started;
  bool get loading => _loading;
  String? get error => _error;

  /// The API's sentence when it refused to hand the document over to this plan (a 403), else null.
  String? get lockMessage => _lock;
  bool get reported => _reported;
  bool get removed => _removed;

  /// An action on [key] (a file id, `delete`, `report`) is on its way to the API.
  bool isBusy(String key) => _busy.contains(key);

  /// The member shared this document, or is a SUPER_ADMIN: they may add files, drop one and delete it.
  bool get mayChange => _doc != null && (_viewer?.mayChange(_doc!) ?? false);

  /// A document the member shared cannot be reported by them (the API says so; the page says nothing).
  bool get isMine => _doc != null && _viewer?.id == _doc!.uploaderId;

  Future<void> start() async {
    _started = true;
    await _load(notify: false);
  }

  Future<void> refresh() => _load(notify: true);

  Future<void> _load({required bool notify}) async {
    _loading = true;
    _error = null;
    if (notify) _notify();
    try {
      final results = await Future.wait<Object?>([
        repository.document(documentId),
        () async {
          try {
            return await repository.viewer();
          } catch (_) {
            return null;
          }
        }(),
      ]);
      _doc = results[0] as LibraryDocument;
      _viewer = results[1] as LibraryViewer?;
    } catch (e) {
      // A page opened with its document in hand stands without the read.
      if (_doc == null) _error = ApiError.from(e).message;
      try {
        _viewer = await repository.viewer();
      } catch (_) {}
    } finally {
      _loading = false;
      _notify();
    }
  }

  void _set(LibraryDocument d) {
    _doc = d;
    onChanged?.call(d);
    _notify();
  }

  // --- reading ---------------------------------------------------------------------

  /// Reads one file for the viewer (`?preview=true`, not a download). The first read of a page counts one
  /// opening of the document (`POST /documents/:id/view`, best effort).
  ///
  /// This is the only way the app reads a file. There is deliberately no download here (owner's call,
  /// 28 Oct 2026: the library is view-only on a phone), so the bytes go to the viewer and nowhere else.
  Future<FileOutcome> preview(LibraryFile file) async {
    final d = _doc;
    if (d == null || _busy.contains(file.id)) return const FileOutcome.failed('Please wait.');
    _busy.add(file.id);
    _lock = null;
    _notify();
    try {
      final bytes = await repository.previewFile(d, file);
      await _countView();
      return FileOutcome.ok(bytes);
    } catch (e) {
      final err = ApiError.from(e);
      final locked = err.statusCode == 403;
      if (locked) _lock = err.message;
      return FileOutcome.failed(err.message, locked: locked);
    } finally {
      _busy.remove(file.id);
      _notify();
    }
  }

  /// One opening of the document, counted once per page however many files are read.
  Future<void> _countView() async {
    if (_viewCounted) return;
    _viewCounted = true;
    try {
      final count = await repository.recordView(documentId);
      final cur = _doc;
      if (cur != null) _set(cur.copyWith(viewCount: count));
    } catch (_) {
      // A popularity counter is not worth failing a read for.
    }
  }

  // --- the member's own documents -----------------------------------------------

  /// Flags the document for the ICR admin team. A sentence when the API refuses (it is the member's own,
  /// or they already reported it: the page then reads "Reported", as the API's 409 says it is under review).
  Future<String?> report(DocumentReportReason reason, {String? note}) async {
    if (_busy.contains('report')) return null;
    _busy.add('report');
    _notify();
    try {
      await repository.report(documentId, reason, note: note);
      _reported = true;
      return null;
    } catch (e) {
      final err = ApiError.from(e);
      if (err.statusCode == 409) _reported = true;
      return err.message;
    } finally {
      _busy.remove('report');
      _notify();
    }
  }

  /// Retires the document; a sentence when the API refuses.
  Future<String?> delete() async {
    if (_busy.contains('delete')) return null;
    _busy.add('delete');
    _notify();
    try {
      await repository.delete(documentId);
      _removed = true;
      onRemoved?.call(documentId);
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _busy.remove('delete');
      _notify();
    }
  }

  /// Drops one file of a pack; the API refuses the last one with its own sentence.
  Future<String?> removeFile(LibraryFile file) async {
    final d = _doc;
    if (d == null || _busy.contains(file.id)) return null;
    _busy.add(file.id);
    _notify();
    try {
      await repository.removeFile(d.id, file.id);
      final cur = _doc ?? d;
      _set(
        cur.copyWith(
          files: [
            for (final f in cur.files)
              if (f.id != file.id) f,
          ],
          fileCount: cur.fileCount - 1,
          totalSizeBytes: cur.totalSizeBytes - file.sizeBytes,
        ),
      );
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _busy.remove(file.id);
      _notify();
    }
  }

  /// The document after files were added to it (the upload form's answer).
  void filesAdded(LibraryDocument updated) => _set(updated);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
