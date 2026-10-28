import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/site_policy.dart';
import 'web_session.dart';

/// A page of the ICR website inside the app: the part of ICR the app has no
/// screen of its own for yet. It keeps the person signed in (the access token
/// goes into the page's storage first, see [WebSessionBridge]), follows the
/// website's own links itself, and hands what a web view should not do to the
/// phone: another site, `mailto:` / `tel:`, a payment, a file to download
/// ([SitePolicy.navigation]).
///
/// Back goes back through the page's own history first, then leaves the screen.
class InAppWebScreen extends StatefulWidget {
  const InAppWebScreen({
    super.key,
    required this.uri,
    this.title,
    this.accessToken,
    this.renewToken,
    this.controller,
    this.launchExternal,
    this.site,
  });

  final Uri uri;

  /// Shown until the page names itself.
  final String? title;

  /// A fresh access token for the page, null when signed out.
  final Future<String?> Function()? accessToken;

  /// A newer one, handed to the open page on a timer; [accessToken] when left out.
  final Future<String?> Function()? renewToken;

  /// A controller made outside (tests).
  final WebViewController? controller;

  /// Hands a link to the phone; the system browser, mail or dialler by default.
  final Future<bool> Function(Uri uri)? launchExternal;

  /// The website's origin; the configured one by default.
  final Uri? site;

  @override
  State<InAppWebScreen> createState() => _InAppWebScreenState();
}

class _InAppWebScreenState extends State<InAppWebScreen> {
  late final WebViewController _web;
  Timer? _renew;
  String? _pendingToken;
  bool _primed = true;
  bool _canGoBack = false;
  int _progress = 0;
  String? _pageTitle;
  Object? _error;

  /// The page the person asked for has painted. Until then the web view sits under a white loading state:
  /// the Android WebView draws black before its first frame, and with a session to carry across it first shows
  /// a static page of the site (`/robots.txt`), neither of which is the app's to show.
  bool _shown = false;

  Uri get _site => widget.site ?? SitePolicy.site;

  @override
  void initState() {
    super.initState();
    _web = widget.controller ?? WebViewController();
    _web
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onProgress: (p) => _set(() => _progress = p),
          onPageStarted: (_) => _set(() => _error = null),
          onPageFinished: _onPageFinished,
          onWebResourceError: (e) {
            if (e.isForMainFrame ?? true) _set(() => _error = e);
          },
          onUrlChange: (_) => _refreshHistory(),
        ),
      );
    unawaited(_start());
  }

  void _set(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _start() async {
    // A page is read fresh every time it opens: a stage the employer moved a minute ago must show, not a
    // copy the view kept from the last visit.
    await _web.clearCache();
    final token = SitePolicy.isSite(widget.uri, site: _site) ? await widget.accessToken?.call() : null;
    if (!mounted) return;
    if (token == null) {
      await _web.loadRequest(widget.uri);
      return;
    }
    // The page reads its session from the origin's storage before it runs, so
    // the storage is filled from a static page of the same origin first.
    _pendingToken = token;
    _primed = false;
    await _web.loadRequest(_site.resolve('/robots.txt'));
  }

  Future<void> _onPageFinished(String url) async {
    final token = _pendingToken;
    if (!_primed && token != null) {
      _primed = true;
      _pendingToken = null;
      await _web.runJavaScript(WebSessionBridge.script(token));
      _renew = Timer.periodic(WebSessionBridge.renewEvery, (_) => _renewSession());
      if (mounted) await _web.loadRequest(widget.uri);
      return;
    }
    final title = await _web.getTitle();
    _set(() {
      _pageTitle = title == null || title.trim().isEmpty ? null : title.trim();
      _shown = true;
    });
    await _refreshHistory();
  }

  Future<void> _renewSession() async {
    final token = await (widget.renewToken ?? widget.accessToken)?.call();
    if (token != null && mounted) await _web.runJavaScript(WebSessionBridge.script(token));
  }

  Future<void> _refreshHistory() async {
    final can = await _web.canGoBack();
    _set(() => _canGoBack = can);
  }

  FutureOr<NavigationDecision> _onNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    // A frame inside the page (an embedded video, a map) is the page's own business.
    if (!request.isMainFrame) return NavigationDecision.navigate;
    if (SitePolicy.navigation(uri, site: _site) == WebNavigation.inApp) return NavigationDecision.navigate;
    unawaited(_external(uri));
    return NavigationDecision.prevent;
  }

  Future<void> _external(Uri uri) async {
    final launch = widget.launchExternal ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication);
    var opened = false;
    try {
      opened = await launch(uri);
    } catch (_) {
      // Treated as "could not open" below.
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Couldn't open ${uri.host.isEmpty ? uri.scheme : uri.host}${uri.path}")));
    }
  }

  Future<void> _back() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
    } else if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    _renew?.cancel();
    // The page's storage outlives this screen: take the session out of it.
    unawaited(_web.runJavaScript(WebSessionBridge.clearScript).catchError((_) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _pageTitle ?? widget.title ?? (widget.uri.host.isEmpty ? 'ICR' : widget.uri.host);
    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _web.goBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Bar(title: title, onBack: _back, onClose: () => Navigator.of(context).maybePop()),
              SizedBox(
                height: 2,
                child: _progress > 0 && _progress < 100
                    ? LinearProgressIndicator(
                        key: const Key('web.progress'),
                        value: _progress / 100,
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        color: AppColors.primary,
                      )
                    : null,
              ),
              Expanded(
                child: _error != null
                    ? _Failed(onRetry: () => _web.reload())
                    : Stack(
                        children: [
                          WebViewWidget(key: const Key('web.view'), controller: _web),
                          // Opaque white, over the web view, until the page has finished: never a black frame.
                          if (!_shown) const Positioned.fill(child: _Loading(key: Key('web.loading'))),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.title, required this.onBack, required this.onClose});

  final String title;
  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          IconButton(
            key: const Key('web.back'),
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 24, color: AppColors.onSurfaceVariant),
          ),
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.barTitle),
          ),
          IconButton(
            key: const Key('web.close'),
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 24, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// What the person sees while the page loads: the app's own white, a spinner and a line, never the platform's black.
class _Loading extends StatelessWidget {
  const _Loading({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.white,
      child: Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3))),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("This page didn't load.", style: AppText.barTitle, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            const Text('Check your connection and try again.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(key: const Key('web.retry'), onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
