import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'support_models.dart';
import 'support_repository.dart';
import 'support_words.dart';

/// The words of a refusal: the API's own sentence, or [fallback] when it said none.
String refusalOf(Object error, String fallback) {
  final e = ApiError.from(error);
  return e.message.startsWith('Something went wrong') ? fallback : e.message;
}

/// "Help & support": the member's requests under a status tab and a search, the common questions above them and the
/// ICR account manager when one is named. The website's `/support` (`MyTicketsList`).
class SupportController extends ChangeNotifier {
  SupportController({required this.repository, this.pageSize = 20});

  final SupportRepository repository;
  final int pageSize;

  SupportFilter filter = SupportFilter.open;
  String search = '';

  List<SupportTicket> tickets = const [];

  /// The first page (or a Retry) is in flight and there is nothing to show yet.
  bool loading = true;
  bool loadingMore = false;
  String? error;
  int _page = 1;
  bool hasNext = false;
  int total = 0;

  List<SupportFaq> faqs = const [];
  AccountManager? manager;

  /// Articles marked as having answered the question this visit.
  final Set<String> helpful = {};
  final Set<String> _viewed = {};

  int _seq = 0;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// The first read: the requests, the common questions and the account manager together. The last two are
  /// optional furniture, so a failure there only leaves them out.
  Future<void> start() async {
    await Future.wait([load(), _loadExtras()]);
  }

  /// A pull to refresh: everything again, keeping what is on screen meanwhile.
  Future<void> refresh() async {
    await Future.wait([load(refresh: true), _loadExtras()]);
  }

  Future<void> _loadExtras() async {
    try {
      faqs = await repository.faqs(limit: 4);
    } catch (_) {
      faqs = const [];
    }
    try {
      manager = await repository.accountManager();
    } catch (_) {
      manager = null;
    }
    _notify();
  }

  /// Reads the first page again. [refresh] keeps what is on screen while it loads (pull to refresh).
  Future<void> load({bool refresh = false}) async {
    final seq = ++_seq;
    if (!refresh) {
      loading = true;
      error = null;
      _notify();
    }
    try {
      final page = await repository.tickets(status: filter.api, search: search, page: 1, limit: pageSize);
      if (seq != _seq) return;
      tickets = page.items;
      _page = page.page;
      hasNext = page.hasNext;
      total = page.total;
      error = null;
    } catch (e) {
      if (seq != _seq) return;
      error = refusalOf(e, SupportWords.couldNotLoad);
      if (!refresh) tickets = const [];
    } finally {
      if (seq == _seq) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (loadingMore || loading || !hasNext) return;
    final seq = _seq;
    loadingMore = true;
    _notify();
    try {
      final page = await repository.tickets(status: filter.api, search: search, page: _page + 1, limit: pageSize);
      if (seq != _seq) return;
      tickets = [...tickets, ...page.items];
      _page = page.page;
      hasNext = page.hasNext;
      total = page.total;
    } catch (e) {
      if (seq == _seq) error = refusalOf(e, SupportWords.couldNotLoad);
    } finally {
      loadingMore = false;
      _notify();
    }
  }

  Future<void> setFilter(SupportFilter next) async {
    if (next == filter) return;
    filter = next;
    await load();
  }

  Future<void> setSearch(String value) async {
    final q = value.trim();
    if (q == search) return;
    search = q;
    await load();
  }

  /// An article was opened: counted once, and never allowed to fail the page.
  void viewed(SupportFaq faq) {
    if (!_viewed.add(faq.id)) return;
    unawaited(repository.markFaqViewed(faq.id));
  }

  void markHelpful(SupportFaq faq) {
    if (!helpful.add(faq.id)) return;
    unawaited(repository.markFaqHelpful(faq.id));
    _notify();
  }
}
