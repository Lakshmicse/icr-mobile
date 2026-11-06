import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/config.dart';
import '../payments/checkout_start.dart';
import '../payments/payment_screen.dart' show PaymentOutcome;
import 'learning_models.dart';

/// Where a paid course place is bought: `POST /learning/courses/:code/checkout` (on a run when one is chosen), which
/// answers the gateway's form; the sample content has no gateway, so the place is confirmed. A seam for tests.
class CourseCheckout {
  CourseCheckout._();

  static Future<CheckoutStart> Function(BuildContext context, Course course, CourseRun? run) start = _api;

  static void reset() => start = _api;

  static Future<CheckoutStart> _api(BuildContext context, Course course, CourseRun? run) async {
    if (AppConfig.demo) return const CheckoutStart(devActivated: true);
    final res = await context.read<ApiClient>().dio.post<Map<String, dynamic>>(
      '/learning/courses/${Uri.encodeComponent(course.code)}/checkout',
      data: {if (run != null) 'batchId': run.id},
    );
    return CheckoutStart.fromJson(res.data ?? const {});
  }
}

/// Buys a paid place on [course] and pays for it in the app's own payment view — the website's enrolment panel,
/// which the app handed to the phone's browser until 4 Nov 2026 ("it should not redirect to the website"). Answers
/// what to tell the member.
Future<String> buyCoursePlace(BuildContext context, Course course, {CourseRun? run}) async {
  try {
    final start = await CourseCheckout.start(context, course, run);
    if (!context.mounted) return '';
    final outcome = await runCheckout(context, start, title: 'Place on ${course.title}');
    return switch (outcome) {
      PaymentOutcome.success => 'Payment received. Your place on ${course.title} is confirmed.',
      PaymentOutcome.failure => "The payment didn't go through. Nothing was charged.",
      PaymentOutcome.cancelled =>
        "The payment wasn't completed. If you did pay, your place is confirmed within a minute.",
    };
  } catch (e) {
    return ApiError.from(e).message;
  }
}
