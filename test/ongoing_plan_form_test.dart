import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_controller.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_models.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_repository.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/ongoing_plan_form.dart';

import 'helpers/fonts.dart';
import 'mentor_offerings_fakes.dart';
import 'mentoring_fakes.dart';

/// "Create a Plan" (owner, 14 Nov 2026: "Create Plan button click and the dialog opened ... just implement how the web
/// is working"): the website's `PlanFormDialog` for an ongoing plan, full screen on a phone.
void main() {
  setUpAll(loadAppFonts);

  Future<(FakeApi, List<bool>)> open(WidgetTester tester, OfferingsWorld world, {OfferedPlan? existing}) async {
    phone(tester, height: 2400);
    final api = world.api();
    final controller = OfferingsController(OfferingsRepository(api: api.client()));
    addTearDown(controller.dispose);
    final results = <bool>[];
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async => results.add(
                await openOngoingPlanForm(
                  context,
                  controller: controller,
                  existing: existing,
                  pickFile: ({required bool imageOnly}) async => pdfFile(name: 'cover.png'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    return (api, results);
  }

  testWidgets("a new plan opens as the website's: ₹25,000 every month, 2 sessions of 1 hour, a draft", (tester) async {
    await open(tester, OfferingsWorld(plans: []));
    expect(find.text('New Ongoing Plan'), findsOneWidget);
    for (final label in [
      'Title *',
      'Description',
      'Cover Image',
      'Price per Term (₹)',
      'Billed Every',
      'Sessions a Month',
      'Session Length',
      'What Else Is Included',
    ]) {
      expect(find.text(label, findRichText: true), findsOneWidget, reason: label);
    }
    expect(find.text('What the mentee is buying, in your own words.'), findsOneWidget);
    expect(find.text('At least ₹500. GST is added at checkout.'), findsOneWidget);
    expect(find.text('The allowance a subscriber may book.'), findsOneWidget);
    expect(find.text('How long each session runs.'), findsOneWidget);
    expect(find.text('One per line, up to 8. Include only what you will actually provide.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('plan-price'))).controller!.text, '25000');
    expect(tester.widget<TextField>(find.byKey(const ValueKey('plan-per-month'))).controller!.text, '2');
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Draft. Hidden from your profile.'), findsOneWidget);
    // Nothing typed yet: the footer says what is missing, as the website's dialog does.
    expect(find.text('Enter a title.'), findsOneWidget);
  });

  testWidgets('each rule is said before Save, then the plan is sent as the website sends it', (tester) async {
    final (api, results) = await open(tester, OfferingsWorld(plans: []));
    await tapKey(tester, 'composer-save');
    expect(api.count('POST /mentor-plans'), 0);
    expect(find.text('Enter a title.'), findsWidgets);

    await typeKey(tester, 'plan-title', 'Mo');
    expect(find.text('Enter a title (at least 3 characters).'), findsOneWidget);
    await typeKey(tester, 'plan-title', 'Monthly leadership coaching');
    await typeKey(tester, 'plan-price', '499');
    expect(find.text('A priced plan starts at ₹500.'), findsOneWidget);
    await typeKey(tester, 'plan-price', '2999');
    await typeKey(tester, 'plan-per-month', '0');
    expect(find.text('Set sessions a month to 1–12.'), findsOneWidget);
    await typeKey(tester, 'plan-per-month', '4');
    await typeKey(tester, 'plan-inclusions', '${'x' * 81}\nChat support');
    expect(find.text('Keep each line of "What Else Is Included" to 80 characters.'), findsOneWidget);
    await typeKey(tester, 'plan-inclusions', 'Two calls a month\n\nChat support between calls');
    expect(find.byKey(const ValueKey('composer-blocker')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('plan-period')));
    await settle(tester);
    await tester.tap(find.text('3 Months').last);
    await settle(tester);
    await tapKey(tester, 'plan-published');
    expect(find.text('Published. Mentees can view and buy this plan.'), findsOneWidget);

    await tapKey(tester, 'composer-save');
    expect(api.bodyOf('POST /mentor-plans'), {
      'title': 'Monthly leadership coaching',
      'coverUrl': null,
      'pricePaisa': 299900,
      'sessionDurationMin': 60,
      'inclusions': ['Two calls a month', 'Chat support between calls'],
      'active': true,
      'kind': 'RECURRING',
      'billingPeriodMonths': 3,
      'sessionsPerMonth': 4,
    });
    expect(results, [true]);
    expect(find.text('New Ongoing Plan'), findsNothing, reason: 'saved: the page closes');
  });

  testWidgets('Free sends price 0; turning Paid back on fills ₹500 rather than ₹0', (tester) async {
    final (api, _) = await open(tester, OfferingsWorld(plans: []));
    await typeKey(tester, 'plan-title', 'Peer circle');
    await tapKey(tester, 'plan-price-free');
    expect(find.byKey(const ValueKey('plan-price')), findsNothing);
    expect(find.text('Nothing is charged for the term.'), findsOneWidget);
    await typeKey(tester, 'plan-title', 'Peer circle');
    await tapKey(tester, 'composer-save');
    expect((api.bodyOf('POST /mentor-plans')! as Map)['pricePaisa'], 0);
  });

  testWidgets('Paid after a cleared price starts again at ₹500', (tester) async {
    await open(tester, OfferingsWorld(plans: []));
    await typeKey(tester, 'plan-price', '');
    await tapKey(tester, 'plan-price-free');
    await tapKey(tester, 'plan-price-paid');
    expect(tester.widget<TextField>(find.byKey(const ValueKey('plan-price'))).controller!.text, '500');
  });

  testWidgets('editing starts from the plan and patches it; the kind is never sent again', (tester) async {
    final world = OfferingsWorld(
      plans: [planJson('plan-coaching', billing: 6, perMonth: 3, sessionMin: 90, inclusions: ['Notes after each call'])],
    );
    final plan = OfferedPlan.fromJson(world.plans.first);
    final (api, _) = await open(tester, world, existing: plan);
    expect(find.text('Edit Ongoing Plan'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('plan-title'))).controller!.text, 'Monthly leadership coaching');
    expect(tester.widget<TextField>(find.byKey(const ValueKey('plan-price'))).controller!.text, '2999');
    expect(find.text('6 Months'), findsOneWidget);
    await typeKey(tester, 'plan-price', '3499');
    await tapKey(tester, 'composer-save');
    final body = api.bodyOf('PATCH /mentor-plans/plan-coaching')! as Map;
    expect(body['pricePaisa'], 349900);
    expect(body['billingPeriodMonths'], 6);
    expect(body['sessionsPerMonth'], 3);
    expect(body['sessionDurationMin'], 90);
    expect(body['inclusions'], ['Notes after each call']);
    expect(body.containsKey('kind'), isFalse);
  });

  testWidgets("a refusal keeps the page open with what was typed and the API's sentence", (tester) async {
    final world = OfferingsWorld(plans: []);
    phone(tester, height: 2400);
    final api = world.api(
      extra: {'POST /mentor-plans': (_) => refuse('Your plan limit is reached.')},
    );
    final controller = OfferingsController(OfferingsRepository(api: api.client()));
    addTearDown(controller.dispose);
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => openOngoingPlanForm(context, controller: controller),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    await typeKey(tester, 'plan-title', 'Monthly leadership coaching');
    await tapKey(tester, 'composer-save');
    expect(find.text('Your plan limit is reached.'), findsOneWidget);
    expect(find.text('New Ongoing Plan'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('plan-title'))).controller!.text, 'Monthly leadership coaching');
  });
}
