import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'enquiries_repository.dart';
import 'enquiry_models.dart';

/// The institute's enquiries on screen: the page read, the status filter, and the two changes a row takes (its
/// status, the institute's note), each written to the API and then into the row.
class EnquiriesController extends ChangeNotifier {
  EnquiriesController(this.repository);

  final EnquiriesRepository repository;

  List<Enquiry> _rows = const [];
  EnquiryReveal? _reveal;
  String _status = '';
  bool _loading = false;
  bool _loadingMore = false;
  int _page = 1;
  int _totalPages = 1;
  String? _error;
  final Set<String> _busy = {};
  int _generation = 0;

  List<Enquiry> get rows => _rows;
  EnquiryReveal? get reveal => _reveal;

  /// `''` for every status, else one of [enquiryStatuses].
  String get status => _status;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _page < _totalPages;
  String? get error => _error;

  /// Whether a change to [id] is on its way.
  bool busy(String id) => _busy.contains(id);

  Future<void> start() => refresh();

  Future<void> refresh() async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await repository.list(status: _status, page: 1);
      if (generation != _generation) return;
      _rows = page.rows;
      _reveal = page.reveal ?? _reveal;
      _page = page.page;
      _totalPages = page.totalPages;
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

  Future<void> setStatus(String status) {
    if (status == _status) return Future.value();
    _status = status;
    return refresh();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !hasMore) return;
    final generation = _generation;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await repository.list(status: _status, page: _page + 1);
      if (generation != _generation) return;
      _rows = [..._rows, ...page.rows];
      _page = page.page;
      _totalPages = page.totalPages;
    } catch (e) {
      if (generation != _generation) return;
      _error = ApiError.from(e).message;
    } finally {
      if (generation == _generation) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Moves one enquiry to [status]. Returns the API's refusal, or null.
  Future<String?> setLeadStatus(String id, String status) => _change(id, status: status);

  /// Saves the institute's note on one enquiry (blank clears it). Returns the API's refusal, or null.
  Future<String?> saveNote(String id, String note) {
    final trimmed = note.trim();
    return _change(id, note: trimmed.isEmpty ? null : trimmed, clearNote: trimmed.isEmpty);
  }

  Future<String?> _change(String id, {String? status, String? note, bool clearNote = false}) async {
    _busy.add(id);
    notifyListeners();
    try {
      final next = await repository.update(id, status: status, note: note, clearNote: clearNote);
      final i = _rows.indexWhere((r) => r.id == id);
      if (i >= 0) {
        // The API's row carries no course and no reveal; keep what the list read and take the two fields that changed.
        _rows = [..._rows]..[i] = _rows[i].copyWith(status: next.status, note: next.note, clearNote: next.note == null);
      }
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    } finally {
      _busy.remove(id);
      notifyListeners();
    }
  }
}
