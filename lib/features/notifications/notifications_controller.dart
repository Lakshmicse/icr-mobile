import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import '../messaging/messaging_models.dart';
import 'notification_models.dart';
import 'notifications_repository.dart';

enum NotificationsTab { all, unread, preferences }

/// When a notification came: today, the six days before, or earlier, by the
/// reader's own midnight (not a rolling 24 hours), as the website groups them.
enum NotificationBucket { today, thisWeek, earlier }

extension NotificationBucketWords on NotificationBucket {
  String get label => switch (this) {
    NotificationBucket.today => 'Today',
    NotificationBucket.thisWeek => 'This week',
    NotificationBucket.earlier => 'Earlier',
  };
}

NotificationBucket bucketOf(DateTime at, DateTime now) {
  final local = now.toLocal();
  final midnight = DateTime(local.year, local.month, local.day);
  final when = at.toLocal();
  if (!when.isBefore(midnight)) return NotificationBucket.today;
  if (!when.isBefore(midnight.subtract(const Duration(days: 6)))) return NotificationBucket.thisWeek;
  return NotificationBucket.earlier;
}

/// The notifications screen: All or Unread a page at a time, grouped by when,
/// with the unread count, reading one or all (at once, put back if the API
/// refuses), and the preferences tab's switches.
class NotificationsController extends ChangeNotifier {
  NotificationsController(this.repository, {DateTime Function()? clock, this.onUnreadChanged})
    : clock = clock ?? DateTime.now;

  final NotificationsRepository repository;
  final DateTime Function() clock;

  /// Told the new unread count whenever it moves here: the bell's dot follows.
  final ValueChanged<int>? onUnreadChanged;

  NotificationsTab _tab = NotificationsTab.all;

  /// The category chip on: the list shows only its rows (the API has no category filter, so this reads
  /// what has been loaded and fetches more while the view is sparse). Null is All.
  String? _categoryId;
  List<AppNotification> _items = const [];
  int _total = 0;
  bool _hasMore = false;
  int _page = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _loaded = false;
  String? _error;
  int _unread = 0;
  NotificationViewer? _viewer;
  int _generation = 0;
  bool _disposed = false;

  List<NotificationPreference>? _preferences;
  bool _preferencesLoading = false;
  String? _preferencesError;
  String? _saveError;

  NotificationsTab get tab => _tab;
  String? get categoryId => _categoryId;
  List<AppNotification> get items => _items;

  /// The rows the list shows: all of them, or the chosen category's.
  List<AppNotification> get visibleItems => _categoryId == null
      ? _items
      : [
          for (final n in _items)
            if (n.category.id == _categoryId) n,
        ];

  /// The categories that have a row among those loaded, in the preferences' order: the chips after Unread.
  List<NotificationCategory> get categoriesPresent {
    final present = {for (final n in _items) n.category.id};
    return [
      for (final c in notificationCategories)
        if (present.contains(c.id)) c,
    ];
  }

  int get total => _total;
  bool get hasMore => _hasMore;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get loaded => _loaded;
  String? get error => _error;
  int get unread => _unread;
  NotificationViewer? get viewer => _viewer;
  List<NotificationPreference>? get preferences => _preferences;
  bool get preferencesLoading => _preferencesLoading;
  String? get preferencesError => _preferencesError;

  /// The last switch the API refused, worded by it.
  String? get saveError => _saveError;

  /// The rows in their groups, in order.
  List<(NotificationBucket, List<AppNotification>)> get groups {
    final now = clock();
    final out = <(NotificationBucket, List<AppNotification>)>[];
    for (final n in visibleItems) {
      final bucket = bucketOf(n.createdAt, now);
      if (out.isNotEmpty && out.last.$1 == bucket) {
        out.last.$2.add(n);
      } else {
        out.add((bucket, [n]));
      }
    }
    return out;
  }

  /// A row names its company only for someone who works for more than one.
  bool showsCompanyOf(AppNotification n) => n.company != null && (_viewer?.companyCount ?? 0) > 1;

  Future<void> start() async {
    await Future.wait([_load(notify: false), _loadUnread(), _loadViewer()]);
  }

  /// Pull to refresh: the list and the count.
  Future<void> refresh() async {
    if (_tab == NotificationsTab.preferences) return loadPreferences();
    await Future.wait([_load(notify: true), _loadUnread()]);
  }

  Future<void> setTab(NotificationsTab tab) async {
    final hadCategory = _categoryId != null;
    _categoryId = null;
    if (tab == _tab) {
      if (hadCategory) _notify();
      return;
    }
    _tab = tab;
    if (tab == NotificationsTab.preferences) {
      _notify();
      if (_preferences == null) await loadPreferences();
      return;
    }
    _items = const [];
    await _load(notify: true);
  }

  /// A category chip: its rows out of All (Unread goes back to All first).
  Future<void> selectCategory(String id) async {
    if (_tab != NotificationsTab.all) {
      _tab = NotificationsTab.all;
      _items = const [];
      _categoryId = id;
      await _load(notify: true);
    } else {
      _categoryId = id;
      _notify();
    }
    await _fillSparse();
  }

  /// While a category is chosen and few of its rows are loaded, read the next page (a few times at most).
  Future<void> _fillSparse() async {
    for (var i = 0; i < 4; i++) {
      if (_categoryId == null || !_hasMore || _loading || _loadingMore || visibleItems.length >= 8) return;
      await loadMore();
    }
  }

  /// "Turn off [category] notifications": the in-app switch of that category, saved on its own. Returns the
  /// API's refusal as a sentence, or null when it is off (a locked category cannot be turned off).
  Future<String?> turnOffCategory(NotificationCategory category) async {
    if (category.locked) return 'These are always sent.';
    if (_preferences == null) await loadPreferences();
    final list = _preferences;
    if (list == null) return _preferencesError ?? 'Your notification preferences could not be loaded.';
    final pref = list.where((p) => p.category.id == category.id).firstOrNull;
    if (pref == null) return 'That setting could not be found.';
    if (!pref.inApp) return null;
    return setChannel(pref, inApp: false);
  }

  Future<void> _load({required bool notify}) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    if (notify) _notify();
    try {
      final page = await repository.list(unreadOnly: _tab == NotificationsTab.unread);
      if (generation != _generation) return;
      _items = page.items;
      _total = page.total;
      _hasMore = page.hasMore;
      _page = 1;
      _loaded = true;
    } catch (e) {
      if (generation != _generation) return;
      _error = ApiError.from(e).message;
    } finally {
      if (generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  /// "Show older notifications": the next page, appended.
  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    _loadingMore = true;
    _notify();
    try {
      final page = await repository.list(page: _page + 1, unreadOnly: _tab == NotificationsTab.unread);
      final known = _items.map((n) => n.id).toSet();
      _items = [..._items, ...page.items.where((n) => !known.contains(n.id))];
      _total = page.total;
      _hasMore = page.hasMore;
      _page++;
    } catch (_) {
      // The next scroll or tap tries again.
    } finally {
      _loadingMore = false;
      _notify();
    }
  }

  Future<void> _loadUnread() async {
    try {
      _setUnread(await repository.unreadCount());
    } catch (_) {}
  }

  Future<void> _loadViewer() async {
    try {
      _viewer = await repository.viewer();
      _notify();
    } catch (_) {}
  }

  void _setUnread(int count) {
    _unread = count < 0 ? 0 : count;
    onUnreadChanged?.call(_unread);
    _notify();
  }

  /// Opening a row reads it; the dot and the count move before the API answers.
  Future<String?> markRead(AppNotification n) async {
    if (!n.unread) return null;
    final beforeItems = _items;
    final beforeUnread = _unread;
    _items = [for (final x in _items) x.id == n.id ? x.read(clock()) : x];
    _setUnread(_unread - 1);
    try {
      await repository.markRead(n.id);
      return null;
    } catch (e) {
      _items = beforeItems;
      _setUnread(beforeUnread);
      return ApiError.from(e).message;
    }
  }

  /// "Mark all as read". On the Unread tab the list empties.
  Future<String?> markAllRead() async {
    if (_unread == 0 && !_items.any((n) => n.unread)) return null;
    final beforeItems = _items;
    final beforeUnread = _unread;
    final now = clock();
    _items = [for (final n in _items) n.read(now)];
    _setUnread(0);
    try {
      await repository.markAllRead();
      if (_tab == NotificationsTab.unread) await _load(notify: true);
      return null;
    } catch (e) {
      _items = beforeItems;
      _setUnread(beforeUnread);
      return ApiError.from(e).message;
    }
  }

  /// Switches the person to [company] before a row about it opens; the API's
  /// refusal (they left it) as a sentence.
  Future<String?> switchTo(ChatCompany company) async {
    try {
      await repository.switchCompany(company.id);
      final v = _viewer;
      _viewer = NotificationViewer(id: v?.id ?? '', activeCompanyId: company.id, companyCount: v?.companyCount ?? 0);
      return null;
    } catch (_) {
      return "You're no longer part of ${company.name}, so this can't open as it.";
    }
  }

  /// Whether opening [n] needs a company switch first.
  bool needsSwitch(AppNotification n) {
    final company = n.company;
    final v = _viewer;
    return company != null && v != null && v.activeCompanyId != company.id;
  }

  // --- preferences ----------------------------------------------------------

  Future<void> loadPreferences() async {
    _preferencesLoading = true;
    _preferencesError = null;
    _notify();
    try {
      _preferences = await repository.preferences();
    } catch (e) {
      _preferencesError = 'Your notification preferences could not be loaded.';
    } finally {
      _preferencesLoading = false;
      _notify();
    }
  }

  /// A switch moves at once and saves on its own; a refusal puts it back.
  Future<String?> setChannel(NotificationPreference p, {bool? inApp, bool? email}) async {
    final list = _preferences;
    if (list == null || p.locked) return null;
    final changed = p.copyWith(inApp: inApp, email: email);
    _preferences = [for (final x in list) x.category.id == p.category.id ? changed : x];
    _saveError = null;
    _notify();
    try {
      _preferences = await repository.savePreference(changed);
      _notify();
      return null;
    } catch (e) {
      _preferences = list;
      final error = ApiError.from(e);
      _saveError = error.statusCode == null ? error.message : 'Your change could not be saved. Try again.';
      _notify();
      return _saveError;
    }
  }

  void clearSaveError() {
    _saveError = null;
    _notify();
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
