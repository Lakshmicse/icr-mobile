import 'package:flutter/widgets.dart';

import 'payment_screen.dart';

/// What a rail's checkout answers — `{ devActivated, action?, fields? }` on every rail: a level or set, a bundle,
/// a course place, a plan, a mentor's service, an event ticket, a job boost. Opened at once in test mode (an API
/// with no gateway keys simulates the payment), else the gateway's address and the fields to post to it.
class CheckoutStart {
  const CheckoutStart({this.devActivated = false, this.action, this.fields = const {}});

  /// Test mode: the API marked it paid itself; there is no gateway leg.
  final bool devActivated;

  /// The gateway's address the fields are posted to.
  final String? action;
  final Map<String, String> fields;

  bool get needsGateway => !devActivated && action != null && action!.isNotEmpty;

  factory CheckoutStart.fromJson(Map<String, dynamic> j) => CheckoutStart(
    devActivated: j['devActivated'] == true,
    action: j['action'] as String?,
    fields: {for (final e in ((j['fields'] as Map?) ?? const {}).entries) e.key.toString(): e.value?.toString() ?? ''},
  );
}

/// Runs what a checkout answered: nothing to do in test mode, else the gateway in the app's own payment view.
/// An answer with neither (the API said the item is payable but sent no form) reads as a failed payment.
Future<PaymentOutcome> runCheckout(BuildContext context, CheckoutStart start, {required String title}) {
  if (start.devActivated) return Future.value(PaymentOutcome.success);
  if (!start.needsGateway) return Future.value(PaymentOutcome.failure);
  return PaymentServices.pay(context, action: start.action!, fields: start.fields, title: title);
}

/// What the person is told when a payment ends, naming what they bought.
String paymentMessage(PaymentOutcome outcome, {required String what}) => switch (outcome) {
  PaymentOutcome.success => 'Payment received. $what is open.',
  PaymentOutcome.failure => "The payment didn't go through. Nothing was charged.",
  PaymentOutcome.cancelled => "The payment wasn't completed. If you did pay, $what opens within a minute.",
};
