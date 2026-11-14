// The user manual's driver: the real app on a simulator, carrying out the commands the
// host sends it (tool/manual/kit.mjs). It is not a test of anything; `flutter test` is
// only the way to get a WidgetTester inside the running app.
//
//   flutter test integration_test/manual_driver_test.dart -d <simulator> \
//     --dart-define=API_BASE_URL=http://localhost:3051/api/v1 --dart-define=SITE_URL=http://localhost:3050
//
// The app asks the host for the next command (GET /next), does it, and answers
// (POST /result). The host photographs the simulator itself, so a picture holds the
// status bar and any web view. Nothing here ships: it lives under integration_test/.
// See tool/manual/README.md.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/app.dart';
import 'package:icr_mobile/core/auth/auth_controller.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/core/util/links.dart';
import 'package:icr_mobile/features/profile/profile_drawer.dart';
import 'package:icr_mobile/features/shell/app_shell.dart';
import 'package:icr_mobile/features/shell/icr_bottom_nav.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

const _host = String.fromEnvironment('MANUAL_HOST', defaultValue: 'http://localhost:3059');

/// The session stays in memory, so a run never reads or leaves a sign-in in the simulator's keychain.
class _MemoryTokens extends TokenStore {
  String? access;
  String? refresh;

  @override
  Future<String?> accessToken() async => access;
  @override
  Future<String?> refreshToken() async => refresh;
  @override
  Future<void> save({required String accessToken, required String refreshToken}) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> clear() async => access = refresh = null;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('manual driver', (t) async {
    // An error inside the app (a screen that fails to build, an image that will not load) must not end the
    // session: it is kept and handed back with the command that was running, as a real phone would carry on.
    final errors = <String>[];
    final reported = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exceptionAsString().split('\n').first);
    try {
      await t.pumpWidget(IcrApp(tokens: _MemoryTokens()));
      await _pumpFor(t, const Duration(milliseconds: 800));
      await _Driver(t, errors).loop();
    } finally {
      FlutterError.onError = reported;
    }
  }, timeout: Timeout.none);
}

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final until = DateTime.now().add(d);
  while (DateTime.now().isBefore(until)) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

class _Driver {
  _Driver(this.t, this.errors);

  final WidgetTester t;

  /// What the app reported since the last answer.
  final List<String> errors;
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 3);

  Future<Map<String, dynamic>?> _get(String path) async {
    try {
      final req = await _http.getUrl(Uri.parse('$_host$path'));
      final res = await req.close().timeout(const Duration(seconds: 40));
      final body = await utf8.decodeStream(res);
      if (res.statusCode != 200 || body.isEmpty) return null;
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _post(String path, Object data) async {
    try {
      final req = await _http.postUrl(Uri.parse('$_host$path'));
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(data)));
      await (await req.close()).drain<void>();
    } catch (_) {}
  }

  Future<void> loop() async {
    while (true) {
      // The host answers when it has a command (a long poll). While no host is running the
      // connection is refused: keep the app alive and ask again.
      Map<String, dynamic>? cmd;
      var answered = false;
      unawaited(_get('/next').then((v) {
        cmd = v;
        answered = true;
      }));
      // One pump at a time: the tester refuses two at once.
      while (!answered) {
        await _pumpFor(t, const Duration(milliseconds: 200));
      }
      if (cmd == null) await _pumpFor(t, const Duration(milliseconds: 700));
      final c = cmd;
      if (c == null || c['do'] == null) continue;
      if (c['do'] == 'quit') {
        await _post('/result', {'id': c['id'], 'ok': true});
        return;
      }
      Object? data;
      String? error;
      try {
        data = await run(c);
      } catch (e) {
        error = e.toString();
      }
      final flutterError = errors.isEmpty ? null : errors.join(' | ');
      errors.clear();
      await _post('/result', {
        'id': c['id'],
        'ok': error == null,
        if (error != null) 'error': error.length > 1200 ? error.substring(0, 1200) : error,
        'data': ?data,
        'flutterError': ?flutterError,
      });
    }
  }

  // --- Finders ---------------------------------------------------------------

  Finder finder(Object? spec) {
    if (spec is String) return find.byKey(Key(spec));
    final s = (spec as Map).cast<String, dynamic>();
    Finder f;
    if (s['key'] != null) {
      f = find.byKey(Key(s['key'] as String));
    } else if (s['text'] != null) {
      f = find.text(s['text'] as String, findRichText: true);
    } else if (s['contains'] != null) {
      f = find.textContaining(s['contains'] as String, findRichText: true);
    } else if (s['tooltip'] != null) {
      f = find.byTooltip(s['tooltip'] as String);
    } else if (s['label'] != null) {
      f = find.bySemanticsLabel(s['label'] as String);
    } else if (s['type'] != null) {
      final name = s['type'] as String;
      f = find.byWidgetPredicate((w) => w.runtimeType.toString() == name);
    } else if (s['keyPrefix'] != null) {
      final p = s['keyPrefix'] as String;
      f = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith(p));
    } else {
      throw ArgumentError('finder needs key, text, contains, tooltip, label, type or keyPrefix: $s');
    }
    if (s['in'] != null) f = find.descendant(of: finder(s['in']), matching: f);
    if (s['ancestor'] != null) {
      // The nearest ancestor of the match that is of this type: the card a title sits in.
      final name = s['ancestor'] as String;
      f = find.ancestor(of: f, matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == name)).first;
    }
    if (s['hit'] == true) f = f.hitTestable();
    if (s['i'] != null) return f.at(s['i'] as int);
    if (s['last'] == true) return f.last;
    return f;
  }

  Finder one(Object? spec) {
    final f = finder(spec);
    final n = f.evaluate().length;
    if (n == 0) throw StateError('nothing matches $spec');
    return n == 1 ? f : f.first;
  }

  Rect? _rectOf(Element e) {
    final r = e.renderObject;
    if (r is RenderBox && r.attached && r.hasSize) return r.localToGlobal(Offset.zero) & r.size;
    return null;
  }

  List<num> _r(Rect r) => [r.left.round(), r.top.round(), r.width.round(), r.height.round()];

  Size get _screen => t.view.physicalSize / t.view.devicePixelRatio;

  Future<bool> waitFor(Object? spec, {int ms = 15000}) async {
    final f = finder(spec);
    final until = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(until)) {
      if (f.evaluate().isNotEmpty) return true;
      await t.pump(const Duration(milliseconds: 120));
    }
    return f.evaluate().isNotEmpty;
  }

  bool _busy() {
    bool found = false;
    void visit(Element e) {
      if (found) return;
      final w = e.widget;
      final name = w.runtimeType.toString();
      if (w is CircularProgressIndicator || w is LinearProgressIndicator || name.contains('Skeleton') || name.contains('Shimmer')) {
        final r = _rectOf(e);
        if (r != null && r.overlaps(Offset.zero & _screen) && r.width > 0) {
          // A determinate bar (course progress) is content, not loading.
          if (w is ProgressIndicator && w.value != null) {
            // not busy
          } else {
            found = true;
            return;
          }
        }
      }
      e.debugVisitOnstageChildren(visit);
    }

    t.binding.rootElement!.debugVisitOnstageChildren(visit);
    return found;
  }

  /// Waits until nothing on screen is loading and it has stayed that way for a moment.
  Future<bool> idle({int ms = 12000, int quiet = 500}) async {
    final until = DateTime.now().add(Duration(milliseconds: ms));
    var calmSince = DateTime.now();
    while (DateTime.now().isBefore(until)) {
      await t.pump(const Duration(milliseconds: 100));
      if (_busy()) {
        calmSince = DateTime.now();
      } else if (DateTime.now().difference(calmSince).inMilliseconds >= quiet) {
        return true;
      }
    }
    return false;
  }

  /// A context under the app's providers (they sit above MaterialApp).
  BuildContext get _appContext => t.element(find.byType(MaterialApp));

  BuildContext get _shellContext {
    final f = find.byType(AppShell, skipOffstage: false);
    if (f.evaluate().isEmpty) throw StateError('not signed in: there is no shell');
    return f.evaluate().first;
  }

  NavigatorState get _nav => t.state<NavigatorState>(find.byType(Navigator, skipOffstage: false).first);

  // --- Commands --------------------------------------------------------------

  Future<Object?> run(Map<String, dynamic> c) async {
    switch (c['do'] as String) {
      case 'ping':
        final auth = _appContext.read<AuthController>();
        return {
          'status': auth.status.name,
          'user': auth.user?.email,
          'role': auth.user?.role,
          'companyId': auth.user?.companyId,
          'screen': [_screen.width, _screen.height],
          'dpr': t.view.devicePixelRatio,
        };

      case 'signOut':
        final auth = _appContext.read<AuthController>();
        if (auth.status == SessionStatus.signedIn) await auth.signOut();
        await _pumpFor(t, const Duration(milliseconds: 600));
        return null;

      case 'become':
        final auth = _appContext.read<AuthController>();
        if (auth.status == SessionStatus.signedIn) {
          await auth.signOut();
          await _pumpFor(t, const Duration(milliseconds: 500));
        }
        await auth.signIn(email: c['email'] as String, password: c['password'] as String, rememberMe: true);
        await _pumpFor(t, const Duration(milliseconds: 900));
        await idle();
        return {'user': auth.user?.email, 'role': auth.user?.role, 'companyId': auth.user?.companyId};

      case 'refreshUser':
        await _appContext.read<AuthController>().refreshUser();
        await _pumpFor(t, const Duration(milliseconds: 600));
        return null;

      case 'open':
        await _guarded(() => openSitePage(_shellContext, c['path'] as String));
        await _pumpFor(t, const Duration(milliseconds: 700));
        await idle();
        return null;

      case 'tab':
        final tab = AppTab.values.firstWhere((x) => x.name == c['name']);
        AppShell.goToTab(_shellContext, tab);
        await _pumpFor(t, const Duration(milliseconds: 500));
        await idle();
        return null;

      case 'drawer':
        AppShell.openDrawer(_shellContext);
        await _pumpFor(t, const Duration(milliseconds: 700));
        await idle();
        return null;

      case 'back':
        await _nav.maybePop();
        await _pumpFor(t, const Duration(milliseconds: 500));
        return null;

      case 'home':
        _nav.popUntil((r) => r.isFirst);
        await _pumpFor(t, const Duration(milliseconds: 400));
        // An open drawer is not a route of its own.
        if (find.byType(Drawer).evaluate().isNotEmpty) {
          await _nav.maybePop();
          await _pumpFor(t, const Duration(milliseconds: 400));
        }
        return null;

      case 'tap':
        final f = one(c['on']);
        if (c['ensure'] != false) {
          try {
            await t.ensureVisible(f);
            await t.pump(const Duration(milliseconds: 200));
          } catch (_) {}
        }
        await t.tap(f, warnIfMissed: false);
        await _pumpFor(t, Duration(milliseconds: (c['after'] as int?) ?? 600));
        if (c['idle'] != false) await idle();
        return null;

      case 'longPress':
        await t.longPress(one(c['on']), warnIfMissed: false);
        await _pumpFor(t, const Duration(milliseconds: 600));
        return null;

      case 'tapAt':
        await t.tapAt(Offset((c['x'] as num).toDouble(), (c['y'] as num).toDouble()));
        await _pumpFor(t, Duration(milliseconds: (c['after'] as int?) ?? 600));
        if (c['idle'] != false) await idle();
        return null;

      case 'enter':
        var f = one(c['on']);
        final w = t.widget(f);
        if (w is! EditableText) {
          final inner = find.descendant(of: f, matching: find.byType(EditableText));
          if (inner.evaluate().isEmpty) throw StateError('no text field inside ${c['on']}');
          f = inner.first;
        }
        try {
          await t.ensureVisible(f);
        } catch (_) {}
        await t.enterText(f, c['text'] as String);
        await _pumpFor(t, const Duration(milliseconds: 350));
        return null;

      case 'action':
        // The keyboard's own button: done, search, next, send.
        final a = TextInputAction.values.firstWhere((x) => x.name == (c['name'] ?? 'done'));
        await t.testTextInput.receiveAction(a);
        await _pumpFor(t, const Duration(milliseconds: 600));
        await idle();
        return null;

      case 'unfocus':
        FocusManager.instance.primaryFocus?.unfocus();
        await _pumpFor(t, const Duration(milliseconds: 300));
        return null;

      case 'swipe':
        final at = c['at'] as List?;
        final start = at != null
            ? Offset((at[0] as num).toDouble(), (at[1] as num).toDouble())
            : Offset(_screen.width / 2, _screen.height * 0.55);
        await t.dragFrom(start, Offset((c['dx'] as num? ?? 0).toDouble(), (c['dy'] as num? ?? 0).toDouble()));
        await _pumpFor(t, const Duration(milliseconds: 700));
        if (c['idle'] != false) await idle(ms: 6000);
        return null;

      case 'scrollTo':
        // Brings a widget into view. A lazy list has not built it yet, so swipe until it exists.
        final spec = c['on'];
        final f = finder(spec);
        final step = (c['step'] as num? ?? 320).toDouble();
        final at = c['at'] as List?;
        final start = at != null
            ? Offset((at[0] as num).toDouble(), (at[1] as num).toDouble())
            : Offset(_screen.width / 2, _screen.height * 0.6);
        for (var i = 0; i < ((c['max'] as int?) ?? 40) && f.evaluate().isEmpty; i++) {
          await t.dragFrom(start, Offset(0, -step));
          await _pumpFor(t, const Duration(milliseconds: 350));
        }
        if (f.evaluate().isEmpty) throw StateError('scrolled without finding $spec');
        await t.ensureVisible(f.first);
        await _pumpFor(t, const Duration(milliseconds: 400));
        final align = c['align'] as num?;
        if (align != null) {
          // Put the widget's top at this fraction of the screen's height, when the list can scroll that far.
          final r = t.getRect(f.first);
          final want = _screen.height * align.toDouble();
          final delta = want - r.top;
          if (delta.abs() > 12) {
            await t.dragFrom(start, Offset(0, delta));
            await _pumpFor(t, const Duration(milliseconds: 500));
          }
        }
        return null;

      case 'wait':
        final ok = await waitFor(c['on'], ms: (c['ms'] as int?) ?? 15000);
        if (!ok) throw StateError('waited, never saw ${c['on']}');
        if (c['idle'] != false) await idle();
        return null;

      case 'gone':
        final f = finder(c['on']);
        final until = DateTime.now().add(Duration(milliseconds: (c['ms'] as int?) ?? 15000));
        while (DateTime.now().isBefore(until) && f.evaluate().isNotEmpty) {
          await t.pump(const Duration(milliseconds: 120));
        }
        if (f.evaluate().isNotEmpty) throw StateError('still there: ${c['on']}');
        return null;

      case 'idle':
        return {'idle': await idle(ms: (c['ms'] as int?) ?? 12000)};

      case 'sleep':
        await _pumpFor(t, Duration(milliseconds: (c['ms'] as int?) ?? 500));
        return null;

      case 'exists':
        return {'n': finder(c['on']).evaluate().length};

      case 'rect':
        final f = finder(c['on']);
        return {
          'rects': [for (final e in f.evaluate().take(8)) if (_rectOf(e) != null) _r(_rectOf(e)!)],
          'dpr': t.view.devicePixelRatio,
        };

      case 'frame':
        // Settle before the host photographs: a couple of frames after the last change.
        if (c['idle'] != false) await idle(ms: (c['ms'] as int?) ?? 12000);
        await _pumpFor(t, const Duration(milliseconds: 250));
        return {
          'dpr': t.view.devicePixelRatio,
          'busy': _busy(),
          'rects': {
            for (final entry in ((c['rects'] as Map?) ?? const {}).entries)
              entry.key as String: [
                for (final e in finder(entry.value).evaluate().take(4))
                  if (_rectOf(e) != null) _r(_rectOf(e)!),
              ],
          },
        };

      case 'dump':
        return _dump(filter: c['filter'] as String?);

      case 'menu':
        // The profile menu as the app builds it for whoever is signed in: the rows, and the pages each opens.
        final drawer = t.widget<AppShell>(find.byType(AppShell, skipOffstage: false).first).drawer;
        if (drawer is! ProfileDrawer) throw StateError('the shell has no profile menu');
        final auth = _appContext.read<AuthController>();
        return {
          'user': auth.user?.email,
          'role': auth.user?.role,
          'companyId': auth.user?.companyId,
          'mentorStatus': auth.user?.mentorStatus,
          'workspaces': [
            for (final w in drawer.workspaces ?? const [])
              {
                'key': w.key,
                'label': w.label,
                'sections': [
                  for (final s in w.sections)
                    {
                      'title': s.title,
                      'items': [
                        for (final i in s.items) {'label': i.label, 'path': i.path},
                      ],
                    },
                ],
              },
          ],
          'doors': [
            for (final d in drawer.doors) {'key': d.key, 'label': d.label, 'caption': d.caption, 'path': d.path},
          ],
          'savedItems': drawer.account.savedItems,
        };

      default:
        throw ArgumentError('unknown command ${c['do']}');
    }
  }

  /// A hand-off that fails inside the app (a 404 record) throws into the zone; report it as this command's error.
  Future<void> _guarded(Future<void> Function() body) async {
    // The opener returns when the pushed screen is closed, so it is never awaited.
    unawaited(body().catchError((Object e) {}));
  }

  Map<String, dynamic> _dump({String? filter}) {
    final screen = Offset.zero & _screen;
    final out = <Map<String, dynamic>>[];
    void visit(Element e) {
      final w = e.widget;
      Map<String, dynamic>? row;
      if (w.key is ValueKey<String>) {
        row = {'k': (w.key! as ValueKey<String>).value, 'type': w.runtimeType.toString()};
      }
      if (w is RichText) {
        final s = w.text.toPlainText().trim();
        if (s.isNotEmpty) (row ??= {})['t'] = s.length > 90 ? '${s.substring(0, 90)}…' : s;
      } else if (w is EditableText) {
        (row ??= {})['field'] = w.controller.text;
      } else if (w is InputDecorator) {
        final d = w.decoration;
        final label = d.labelText ?? d.hintText;
        if (label != null) (row ??= {})['input'] = label;
      } else if (w is Tooltip) {
        if (w.message != null) (row ??= {})['tip'] = w.message;
      }
      if (row != null) {
        final r = _rectOf(e);
        if (r != null && r.overlaps(screen) && r.width > 0 && r.height > 0) {
          row['r'] = _r(r);
          out.add(row);
        }
      }
      e.debugVisitOnstageChildren(visit);
    }

    t.binding.rootElement!.debugVisitOnstageChildren(visit);
    final rows = filter == null
        ? out
        : out.where((r) => r.values.any((v) => v.toString().toLowerCase().contains(filter.toLowerCase()))).toList();
    return {'screen': [_screen.width, _screen.height], 'rows': rows};
  }
}
