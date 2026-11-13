import 'package:flutter/widgets.dart';

import '../../core/api/api_error.dart';
import '../payments/checkout_start.dart';
import '../payments/payment_screen.dart' show PaymentOutcome;
import 'event_models.dart';
import 'events_repository.dart';

/// Buys a ticket to a priced [event] and pays for it in the app's own payment view (the website's "Get tickets",
/// which the app handed to the phone's browser until 4 Nov 2026: "it should not redirect to the website"). Answers
/// what to tell the member; [onPaid] runs when the seat is theirs, to read the event again.
Future<String> buyEventTicket(
  BuildContext context,
  EventsRepository repository,
  EventSummary event, {
  Future<void> Function()? onPaid,
}) async {
  try {
    final start = await repository.buyTicket(event);
    if (!context.mounted) return '';
    final outcome = await runCheckout(context, start, title: 'Ticket for ${event.title}');
    if (outcome == PaymentOutcome.success) await onPaid?.call();
    return switch (outcome) {
      PaymentOutcome.success => 'Payment received. Your seat is confirmed.',
      PaymentOutcome.failure => 'The payment failed. You were not charged.',
      PaymentOutcome.cancelled =>
        'The payment was not completed. If you paid, your seat will be confirmed within a minute.',
    };
  } catch (e) {
    return ApiError.from(e).message;
  }
}
