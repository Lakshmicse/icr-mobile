import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'event_models.dart';
import 'events_repository.dart';

/// One event's sheet: the full event with its programme and the member's
/// place, and the member's actions on it.
class EventDetailController extends ChangeNotifier {
  EventDetailController({required this.repository, required EventSummary seed, this.onChanged})
    : _detail = EventDetail(event: seed);

  final EventsRepository repository;

  /// Tells the board when the event's place or bookmark changes.
  final ValueChanged<EventSummary>? onChanged;

  EventDetail _detail;
  bool _loading = true;
  bool _busy = false;
  bool _disposed = false;
  String? _error;

  EventDetail get detail => _detail;
  EventSummary get event => _detail.event;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final seed = _detail.event;
      final full = await repository.detail(seed);
      _detail = full.copyWith(event: full.event.copyWith(saved: seed.saved || full.event.saved));
    } catch (e) {
      _error = ApiError.from(e).message;
    }
    _loading = false;
    _notify();
  }

  /// Takes a place; a sentence when the API refuses. The place is drawn at
  /// once; once the API has kept it the pass card is filled in, and the board
  /// is told again (its schedule reads what the repository knows by then).
  Future<String?> register() async {
    final before = event;
    _busy = true;
    _set(event.copyWith(rsvp: RsvpState.going, going: event.going + 1));
    try {
      final state = await repository.rsvp(before);
      if (state != RsvpState.going) _set(event.copyWith(rsvp: state, going: event.going - 1));
      _detail = _detail.copyWith(pass: await _passFor(event));
      onChanged?.call(event);
      return null;
    } catch (e) {
      _set(before);
      return ApiError.from(e).message;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Gives the place back; a sentence when the API refuses.
  Future<String?> cancel() async {
    final before = _detail;
    final was = event;
    _busy = true;
    _detail = _detail.copyWith(clearPass: true);
    _set(was.copyWith(rsvp: RsvpState.cancelled, going: was.rsvp == RsvpState.going ? was.going - 1 : was.going));
    try {
      await repository.cancel(was);
      onChanged?.call(event);
      return null;
    } catch (e) {
      _detail = before;
      _set(was);
      return ApiError.from(e).message;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void toggleSave() => _set(event.copyWith(saved: !event.saved));

  Future<EventPass?> _passFor(EventSummary e) async {
    try {
      return await repository.passFor(e);
    } catch (_) {
      return null; // the place is kept; the pass card waits for the next load
    }
  }

  void _set(EventSummary e) {
    _detail = _detail.copyWith(event: e);
    onChanged?.call(e);
    _notify();
  }
}
