import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'site_policy.dart';

/// The website page [uri] names, path and query (`/jobs/123`, `/company?tab=team`); null for another site.
String? sitePlaceOf(Uri uri) {
  if (!SitePolicy.isSite(uri)) return null;
  return uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
}

/// Marks the page of the website a screen stands for (`/jobs/123`, `/messaging?c=abc`), so the app can open the
/// same screen again when Android brings it back after ending it in the background ([ScreenTrail]). Draws [child]
/// unchanged; a null [path] marks nothing.
class SitePlace extends StatelessWidget {
  const SitePlace({super.key, required this.path, required this.child});

  final String? path;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// The screens pushed over the app (pages and sheets, never a dialog), and the website page each one stands for.
///
/// Android ends an app in the background when another app needs the memory (a camera, a video, WhatsApp on a
/// phone with little to spare), and a Flutter app then starts again from its first screen when the person comes
/// back (owner, 14 Nov 2026: "the ICR will refresh from current screen to home screen"). The shell keeps [place] in
/// the activity's saved state and opens it again through `SiteRoutes`, the same way a link to that page opens.
///
/// A screen gets its place in one of two ways: it was opened for a page of the website (`SiteRoutes.inApp` hands
/// the page to [opening], and the next screen pushed takes it), or it says so itself with [SitePlace].
class ScreenTrail extends NavigatorObserver with ChangeNotifier {
  ScreenTrail();

  /// The one on the app's navigator (`MaterialApp.navigatorObservers`).
  static final instance = ScreenTrail();

  final _routes = <Route<dynamic>>[];
  final _places = Expando<String>('site place');
  _Opening? _opening;
  bool _notifyScheduled = false;

  /// Runs [open], an opener for [path]: the first page or sheet it pushes stands for [path]. Nothing is given away
  /// once the opener is done (it showed a tab, or the record could not be read).
  Future<void> opening(String path, Future<void> Function() open) {
    final mine = _Opening(path);
    _opening = mine;
    void release() {
      if (identical(_opening, mine)) _opening = null;
    }

    try {
      return open().whenComplete(release);
    } catch (_) {
      release();
      rethrow;
    }
  }

  /// The website page of the top-most screen that has one: what the person was looking at. Null on a tab, or when
  /// nothing pushed over the tabs has a page.
  String? get place {
    // A navigator that went away (a session ended, a test's app) takes its routes with it unannounced.
    _routes.removeWhere((route) => route.navigator == null);
    for (final route in _routes.reversed) {
      if (route.isFirst) continue;
      // What the screen says it is now (a workspace on another of its pages) before what it was opened for.
      final path = _markedIn(route) ?? _places[route];
      if (path != null) return path;
    }
    return null;
  }

  static bool _isScreen(Route<dynamic> route) => route is PageRoute || route is ModalBottomSheetRoute;

  /// The first [SitePlace] in [route]'s screen, outermost first.
  static String? _markedIn(Route<dynamic> route) {
    if (route is! ModalRoute) return null;
    final context = route.subtreeContext;
    if (context is! Element) return null;
    String? found;
    void visit(Element element) {
      if (found != null) return;
      final widget = element.widget;
      if (widget is SitePlace && widget.path != null) {
        found = widget.path;
        return;
      }
      element.visitChildren(visit);
    }

    visit(context);
    return found;
  }

  /// Listeners hear a frame later, once the new screen is built and its [SitePlace] can be found.
  void _changed() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    }, debugLabel: 'ScreenTrail');
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_isScreen(route)) return;
    _routes
      ..removeWhere((r) => r.navigator == null)
      ..add(route);
    final opening = _opening;
    if (opening != null) {
      _places[route] = opening.path;
      _opening = null;
    }
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_routes.remove(route)) _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_routes.remove(route)) _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final at = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (at >= 0) _routes.removeAt(at);
    if (newRoute != null && _isScreen(newRoute)) _routes.insert(at >= 0 ? at : _routes.length, newRoute);
    _changed();
  }
}

class _Opening {
  _Opening(this.path);

  final String path;
}
