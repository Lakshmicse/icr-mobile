import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/payments/checkout_start.dart';
import 'package:icr_mobile/features/payments/payment_screen.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// Payments run in the app (owner's call, 2 Nov 2026): the gateway's form is posted inside the app's own payment
/// view, a UPI app's link is opened by the phone, and the website page the API's callback sends the member back
/// to ends the payment.
void main() {
  final site = Uri.parse('https://site.test');

  group('where a payment navigation goes', () {
    PaymentNavigation nav(String url) => paymentNavigation(Uri.parse(url), site: site);

    test("the gateway's and the bank's pages stay in the view; the API's return leg too", () {
      expect(nav('https://secure.payu.in/_payment'), PaymentNavigation.inView);
      expect(nav('https://acs.bank.example/3ds?txn=1'), PaymentNavigation.inView);
      expect(nav('https://site.test/api/v1/learning/assessment-payu/callback'), PaymentNavigation.inView);
      expect(nav('about:blank'), PaymentNavigation.inView);
    });

    test("a payment app's link goes to the phone", () {
      expect(nav('upi://pay?pa=icr.payu@mairtel&am=4.43'), PaymentNavigation.phone);
      expect(nav('intent://pay?pa=x#Intent;scheme=upi;package=net.one97.paytm;end'), PaymentNavigation.phone);
      expect(nav('tez://upi/pay?pa=x'), PaymentNavigation.phone);
      expect(nav('phonepe://pay?pa=x'), PaymentNavigation.phone);
    });

    test("a page of the website is the way back: the callback has run", () {
      expect(nav('https://site.test/learning/assessment/cp?status=success'), PaymentNavigation.returned);
      expect(nav('https://site.test/membership?status=failure'), PaymentNavigation.returned);
    });

    test('the outcome is read from the return page', () {
      expect(outcomeOf(Uri.parse('https://site.test/x?status=success')), PaymentOutcome.success);
      expect(outcomeOf(Uri.parse('https://site.test/x?a=1&status=failure')), PaymentOutcome.failure);
      expect(outcomeOf(Uri.parse('https://site.test/x')), PaymentOutcome.cancelled);
    });

    test("an Android intent link is turned into the app's own scheme; other links pass as they are", () {
      expect(
        phoneLinkOf(Uri.parse('intent://pay?pa=icr@upi&am=5#Intent;scheme=upi;package=net.one97.paytm;end')),
        Uri.parse('upi://pay?pa=icr@upi&am=5'),
      );
      expect(phoneLinkOf(Uri.parse('upi://pay?pa=x')), Uri.parse('upi://pay?pa=x'));
      expect(phoneLinkOf(Uri.parse('intent://pay?pa=x')), Uri.parse('intent://pay?pa=x'), reason: 'no Intent tail');
    });
  });

  group("the gateway's form", () {
    test('posts every field to the address the moment it loads, escaped', () {
      final html = gatewayFormHtml('https://secure.payu.in/_payment', {
        'key': 'abc',
        'productinfo': 'Level "Foundation" & more',
        'surl': 'https://site.test/api/v1/learning/assessment-payu/callback',
      });
      expect(html, contains('<form id="pay" method="post" action="https://secure.payu.in/_payment">'));
      expect(html, contains('<input type="hidden" name="key" value="abc">'));
      expect(html, contains('value="Level &quot;Foundation&quot; &amp; more"'));
      expect(html, contains("document.getElementById('pay').submit();"));
      expect(html, isNot(contains('"Foundation"')), reason: 'a quote in a value never breaks the markup');
    });

    test("opens on ICR's logo when it is given, and on the words alone when it is not", () {
      final withLogo = gatewayFormHtml('https://secure.payu.in/_payment', {'key': 'abc'}, logoDataUri: 'data:image/png;base64,AAAA');
      expect(withLogo, contains('<img src="data:image/png;base64,AAAA" alt="ICR – Institute for Corporate Real Estate">'));
      expect(withLogo, contains('Taking you to the secure payment page…'));
      final plain = gatewayFormHtml('https://secure.payu.in/_payment', {'key': 'abc'});
      expect(plain, isNot(contains('<img')));
      expect(plain, contains('Taking you to the secure payment page…'));
    });

    test('a checkout answer is read from the API, with every field as text', () {
      final start = CheckoutStart.fromJson({
        'devActivated': false,
        'action': 'https://secure.payu.in/_payment',
        'fields': {'key': 'abc', 'amount': 2360, 'udf1': null},
      });
      expect(start.needsGateway, isTrue);
      expect(start.fields, {'key': 'abc', 'amount': '2360', 'udf1': ''});
      expect(CheckoutStart.fromJson({'devActivated': true}).needsGateway, isFalse);
      expect(const CheckoutStart().needsGateway, isFalse, reason: 'payable but no form: nothing to post');
    });
  });

  group('running a checkout', () {
    tearDown(PaymentServices.reset);

    testWidgets('test mode is paid at once; a form goes to the payment view; no form is a failure', (tester) async {
      final asked = <String>[];
      PaymentServices.pay = (_, {required action, required fields, title = 'Payment'}) async {
        asked.add('$title → $action ${fields['txnid']}');
        return PaymentOutcome.success;
      };
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(await runCheckout(context, const CheckoutStart(devActivated: true), title: 'x'), PaymentOutcome.success);
      expect(asked, isEmpty, reason: 'nothing to post in test mode');
      expect(
        await runCheckout(
          context,
          const CheckoutStart(action: 'https://pay.test/p', fields: {'txnid': 'T9'}),
          title: 'Pay for Foundation',
        ),
        PaymentOutcome.success,
      );
      expect(asked, ['Pay for Foundation → https://pay.test/p T9']);
      expect(await runCheckout(context, const CheckoutStart(), title: 'x'), PaymentOutcome.failure);
    });

    test('what the person is told', () {
      expect(paymentMessage(PaymentOutcome.success, what: 'Foundation'), 'Payment received. Foundation is open.');
      expect(paymentMessage(PaymentOutcome.failure, what: 'Foundation'), contains('Nothing was charged'));
      expect(paymentMessage(PaymentOutcome.cancelled, what: 'Foundation'), contains('opens within a minute'));
    });
  });

  group('the payment view', () {
    late _FakeWebPlatform platform;
    setUp(() {
      platform = _FakeWebPlatform();
      WebViewPlatform.instance = platform;
    });

    Future<({_FakeController web, List<Uri> phone, PaymentOutcome? Function() outcome})> open(
      WidgetTester tester,
    ) async {
      final phone = <Uri>[];
      PaymentOutcome? outcome;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () async {
                  outcome = await Navigator.of(c).push<PaymentOutcome>(
                    MaterialPageRoute(
                      builder: (_) => PaymentScreen(
                        action: 'https://secure.payu.in/_payment',
                        fields: const {'txnid': 'T1'},
                        title: 'Pay for Foundation',
                        site: site,
                        launchExternal: (u) async {
                          phone.add(u);
                          return true;
                        },
                      ),
                    ),
                  );
                },
                child: const Text('pay'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('pay'));
      await tester.pumpAndSettle();
      return (web: platform.controllers.single, phone: phone, outcome: () => outcome);
    }

    testWidgets("loads the gateway's form, follows its pages, and ends on the website's return page", (tester) async {
      final v = await open(tester);
      expect(find.text('Pay for Foundation'), findsOneWidget);
      expect(v.web.html.single, contains('action="https://secure.payu.in/_payment"'));
      final d = v.web.delegate;
      expect(
        await d.onNavigationRequest!(const NavigationRequest(url: 'https://secure.payu.in/upi', isMainFrame: true)),
        NavigationDecision.navigate,
      );
      expect(
        await d.onNavigationRequest!(
          const NavigationRequest(url: 'https://site.test/api/v1/learning/assessment-payu/callback', isMainFrame: true),
        ),
        NavigationDecision.navigate,
        reason: 'the return leg runs in the view',
      );
      expect(
        await d.onNavigationRequest!(
          const NavigationRequest(url: 'https://site.test/learning/assessment/cp?status=success', isMainFrame: true),
        ),
        NavigationDecision.prevent,
      );
      await tester.pumpAndSettle();
      expect(v.outcome(), PaymentOutcome.success);
      expect(find.byType(PaymentScreen), findsNothing, reason: 'the view closes itself on the way back');
      expect(v.phone, isEmpty);
    });

    testWidgets('a UPI link is opened by the phone and the view stays; Close gives the payment up', (tester) async {
      final v = await open(tester);
      expect(
        await v.web.delegate.onNavigationRequest!(
          const NavigationRequest(url: 'intent://pay?pa=icr@upi#Intent;scheme=upi;package=net.one97.paytm;end', isMainFrame: true),
        ),
        NavigationDecision.prevent,
      );
      await tester.pump();
      expect(v.phone.single, Uri.parse('upi://pay?pa=icr@upi'));
      expect(find.byType(PaymentScreen), findsOneWidget);
      // ICR's logo and name sit over the gateway's page the whole time (owner, 3 Nov 2026).
      expect(find.byKey(const ValueKey('payment-logo')), findsOneWidget);
      expect(find.bySemanticsLabel('ICR – Institute for Corporate Real Estate'), findsOneWidget);
      expect(find.text('Secure payment'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('payment-close')));
      await tester.pumpAndSettle();
      expect(v.outcome(), PaymentOutcome.cancelled);
    });

    testWidgets('a failed return says so', (tester) async {
      final v = await open(tester);
      await v.web.delegate.onNavigationRequest!(
        const NavigationRequest(url: 'https://site.test/membership?status=failure', isMainFrame: true),
      );
      await tester.pumpAndSettle();
      expect(v.outcome(), PaymentOutcome.failure);
    });
  });
}

// ── A web view that draws nothing and remembers what it was asked ─────────────────────────────────────────
class _FakeWebPlatform extends WebViewPlatform {
  final controllers = <_FakeController>[];

  @override
  PlatformWebViewController createPlatformWebViewController(PlatformWebViewControllerCreationParams params) {
    final c = _FakeController(params);
    controllers.add(c);
    return c;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(PlatformNavigationDelegateCreationParams params) =>
      _FakeDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) =>
      _FakeWidget(params);
}

class _FakeController extends PlatformWebViewController {
  _FakeController(super.params) : super.implementation();

  final html = <String>[];
  late _FakeDelegate delegate;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async =>
      delegate = handler as _FakeDelegate;

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async => this.html.add(html);
}

class _FakeDelegate extends PlatformNavigationDelegate {
  _FakeDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback onNavigationRequest) async =>
      this.onNavigationRequest = onNavigationRequest;

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}
}

class _FakeWidget extends PlatformWebViewWidget {
  _FakeWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
