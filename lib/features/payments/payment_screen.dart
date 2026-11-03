import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/util/site_policy.dart';

/// How a payment ended, as far as the app can tell.
enum PaymentOutcome {
  /// The gateway sent the member back with `status=success`: the API has recorded the payment (its callback ran
  /// before the member was sent back), and whatever was bought is open or booked.
  success,

  /// The gateway sent the member back with `status=failure`: nothing was charged.
  failure,

  /// The member closed the payment before the gateway answered. The order waits for the gateway's own notice
  /// (the API's webhook and its reconciliation sweep), so a payment that did go through still lands.
  cancelled,
}

/// Where the payment view sends a navigation.
enum PaymentNavigation {
  /// The gateway's pages, the bank's, and the API's return leg: the view follows them.
  inView,

  /// A UPI or wallet app's own link (`upi:`, `intent:`, `tez:`, `phonepe:`…): the phone opens the app, and the
  /// gateway's page waits for it in the view.
  phone,

  /// A page of the ICR website: the gateway's callback has run and sent the member back, so the payment is over.
  returned,
}

/// What the payment view does with [uri]. The website's own pages end the payment (the API's callback redirects
/// there with `?status=`); the API's paths are the callback leg and stay in the view; every other http(s) host —
/// PayU, a bank's 3-D Secure page — stays in the view; any other scheme is a payment app the phone opens.
PaymentNavigation paymentNavigation(Uri uri, {Uri? site}) {
  if (uri.scheme == 'about' || uri.scheme == 'data' || uri.scheme == 'blob') return PaymentNavigation.inView;
  if (uri.scheme != 'http' && uri.scheme != 'https') return PaymentNavigation.phone;
  if (SitePolicy.isSite(uri, site: site)) {
    return uri.path.startsWith('/api/') ? PaymentNavigation.inView : PaymentNavigation.returned;
  }
  return PaymentNavigation.inView;
}

/// The outcome a return to the website carries: the API's callback appends `status=success|failure`.
PaymentOutcome outcomeOf(Uri returned) => switch (returned.queryParameters['status']) {
  'success' => PaymentOutcome.success,
  'failure' => PaymentOutcome.failure,
  _ => PaymentOutcome.cancelled,
};

/// ICR's logo (the mark and "ICR · Institute for Corporate Real Estate"), shown over every payment.
const icrPaymentLogo = 'assets/images/brand/icr-logo.png';

/// A page that posts the gateway's fields to its address the moment it loads: what the website's `postToGateway`
/// does with a form it builds in the browser, written out so a web view can load it as a page of its own. With
/// [logoDataUri] it opens on ICR's logo (owner, 3 Nov 2026: the payment page lands on ICR's name and logo).
String gatewayFormHtml(String action, Map<String, String> fields, {String? logoDataUri}) {
  final esc = const HtmlEscape(HtmlEscapeMode.attribute).convert;
  final inputs = fields.entries
      .map((e) => '<input type="hidden" name="${esc(e.key)}" value="${esc(e.value)}">')
      .join('\n');
  return '''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Payment</title>
<style>body{font-family:Roboto,sans-serif;color:#1d2939;background:#fff;margin:0;padding:48px 24px;text-align:center}
img{height:64px;max-width:80%;margin:0 auto 20px;display:block}
p{font-size:15px;line-height:1.5;color:#475467}</style></head>
<body>${logoDataUri == null ? '' : '<img src="${esc(logoDataUri)}" alt="ICR – Institute for Corporate Real Estate">'}
<p>Taking you to the secure payment page…</p>
<form id="pay" method="post" action="${esc(action)}">
$inputs
<noscript><button type="submit">Continue to payment</button></noscript>
</form>
<script>document.getElementById('pay').submit();</script>
</body></html>''';
}

/// An `intent://…#Intent;scheme=upi;package=…;end` link, as Android apps advertise themselves, turned into the
/// plain scheme link the phone can open; any other link is returned as it is.
Uri phoneLinkOf(Uri uri) {
  if (uri.scheme != 'intent') return uri;
  final raw = uri.toString();
  final hash = raw.indexOf('#Intent;');
  if (hash < 0) return uri;
  final body = raw.substring('intent://'.length, hash);
  final scheme = RegExp(r';scheme=([^;]+);').firstMatch(raw.substring(hash))?.group(1);
  return scheme == null ? uri : Uri.parse('$scheme://$body');
}

/// Runs a payment inside the app: the gateway's hosted page in a web view of the app's own, a UPI or wallet app
/// opened by the phone when the member picks one, and the way back read from the website's return page. Until
/// 2 Nov 2026 every "Pay" handed the website's page to the phone's browser (owner's call: "all payments should
/// be in the app itself").
Future<PaymentOutcome> payInApp(
  BuildContext context, {
  required String action,
  required Map<String, String> fields,
  String title = 'Payment',
}) async {
  final outcome = await Navigator.of(context).push<PaymentOutcome>(
    MaterialPageRoute<PaymentOutcome>(
      fullscreenDialog: true,
      builder: (_) => PaymentScreen(action: action, fields: fields, title: title),
    ),
  );
  return outcome ?? PaymentOutcome.cancelled;
}

/// The seams the payment goes through, so a test (or a build with no gateway) can stand in for the web view and
/// the phone.
class PaymentServices {
  PaymentServices._();

  /// Runs a payment and answers how it ended; [payInApp] by default.
  static Future<PaymentOutcome> Function(
    BuildContext context, {
    required String action,
    required Map<String, String> fields,
    String title,
  })
  pay = payInApp;

  static void reset() => pay = payInApp;
}

/// The payment view: the gateway's page, a thin progress line, and a close that gives the payment up.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.action,
    required this.fields,
    this.title = 'Payment',
    this.controller,
    this.launchExternal,
    this.site,
  });

  final String action;
  final Map<String, String> fields;
  final String title;

  /// A controller made outside (tests).
  final WebViewController? controller;

  /// Opens a payment app's link with the phone; `url_launcher` by default.
  final Future<bool> Function(Uri uri)? launchExternal;

  /// The website's origin; the configured one by default.
  final Uri? site;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final WebViewController _web;
  int _progress = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _web = widget.controller ?? WebViewController();
    unawaited(_start());
  }

  Future<void> _start() async {
    await _web.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _web.setBackgroundColor(Colors.white);
    await _web.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: _onNavigationRequest,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      ),
    );
    await _web.loadHtmlString(gatewayFormHtml(widget.action, widget.fields, logoDataUri: await _logoDataUri()));
  }

  /// ICR's logo as a data URI for the hand-off page; null (no picture, the words alone) if it cannot be read.
  static Future<String?> _logoDataUri() async {
    try {
      final bytes = await rootBundle.load(icrPaymentLogo);
      return 'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes))}';
    } catch (_) {
      return null;
    }
  }

  FutureOr<NavigationDecision> _onNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (!request.isMainFrame) return NavigationDecision.navigate;
    switch (paymentNavigation(uri, site: widget.site)) {
      case PaymentNavigation.inView:
        return NavigationDecision.navigate;
      case PaymentNavigation.phone:
        unawaited(_openWithPhone(uri));
        return NavigationDecision.prevent;
      case PaymentNavigation.returned:
        _finish(outcomeOf(uri));
        return NavigationDecision.prevent;
    }
  }

  Future<void> _openWithPhone(Uri uri) async {
    final launch = widget.launchExternal ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication);
    var opened = false;
    try {
      opened = await launch(phoneLinkOf(uri));
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("That payment app isn't on this phone. Pick another way to pay.")));
    }
  }

  void _finish(PaymentOutcome outcome) {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(PaymentOutcome.cancelled);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          // ICR's logo and name over every payment, PayU's page included (owner, 3 Nov 2026), then what is paid for.
          title: Row(
            children: [
              Image.asset(
                icrPaymentLogo,
                key: const ValueKey('payment-logo'),
                height: 30,
                fit: BoxFit.contain,
                semanticLabel: 'ICR – Institute for Corporate Real Estate',
              ),
              const SizedBox(width: 12),
              const SizedBox(height: 28, child: VerticalDivider(width: 1, thickness: 1, color: AppColors.cardRule)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppText.plexSans(14, FontWeight.w600, AppColors.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        const Icon(Icons.lock_outline, size: 12, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('Secure payment', style: AppText.plexSans(12, FontWeight.w400, AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              key: const ValueKey('payment-close'),
              tooltip: 'Close',
              icon: const Icon(Icons.close, color: AppColors.onSurface),
              onPressed: () => _finish(PaymentOutcome.cancelled),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: _progress < 100
                ? LinearProgressIndicator(
                    key: const ValueKey('payment-progress'),
                    // Determinate from the start (an empty bar, then the page's progress): an indeterminate one would animate
                    // for ever, which also keeps a test from settling.
                    value: _progress / 100,
                    minHeight: 2,
                    backgroundColor: AppColors.surfaceContainer,
                    color: AppColors.primary,
                  )
                : const SizedBox(height: 2),
          ),
        ),
        body: WebViewWidget(key: const ValueKey('payment-web'), controller: _web),
      ),
    );
  }
}
