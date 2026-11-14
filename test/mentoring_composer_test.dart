/// The 1:1 mentoring composer (`lib/features/mentor_desk/offerings/mentoring_composer.dart`), against the stateful
/// fake of the offerings API: the count decides the engine (one session is a ONE_ON_ONE service, two to twenty-four a
/// CURRICULUM plan), crossing carries the fields over, editing is held to its side, and each save sends exactly the
/// body the website's composer sends.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/mentoring_composer.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_controller.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_files.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_models.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_repository.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_rules.dart';
import 'package:icr_mobile/features/mentorship_my/mentoring_clock.dart';

import 'helpers/fonts.dart';
import 'mentor_offerings_fakes.dart';
import 'mentoring_fakes.dart';

/// `GET /mentorship/mentors/me` for the mentor whose desk this is: the ways they meet and their weekly hours.
Map<String, Object?> mentorMe({
  List<String> modes = const ['VIDEO', 'PHONE'],
  List<Map<String, Object?>> blocks = const [],
  String timezone = 'Asia/Kolkata',
}) => {
  'id': 'mp-anand',
  'status': 'APPROVED',
  'bioHtml': '<p>Twenty years in facilities.</p>',
  'preferredModes': modes,
  'cadence': 'BIWEEKLY',
  'capacity': 3,
  'openSlots': 1,
  'timezone': timezone,
  'availabilityNote': null,
  'meetingLink': null,
  'discoverable': true,
  'availabilityBlocks': blocks,
};

class _Host {
  _Host(this.api, this.controller);

  final FakeApi api;
  final OfferingsController controller;

  /// What each opening resolved to (true when it saved).
  final results = <bool>[];
  int settingsOpened = 0;
}

PickedUpload _png({int bytes = 2048}) =>
    PickedUpload(bytes: Uint8List.fromList(List.filled(bytes, 7)), name: 'cover.png', mimeType: 'image/png');

/// Opens the composer from a button, over a controller that has read the storefront and the plans.
Future<_Host> _open(
  WidgetTester tester, {
  OfferingsWorld? world,
  Map<String, Reply> extra = const {},
  Map<String, Object?>? me,
  OfferedService? Function(OfferingsController c)? service,
  OfferedPlan? Function(OfferingsController c)? plan,
  bool settingsLink = true,
  OfferingFilePicker? pickFile,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width * 2, 16000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final w = world ?? OfferingsWorld();
  final api = w.api(extra: {'GET /mentorship/mentors/me': (_) => me ?? mentorMe(), ...extra});
  final c = OfferingsController(OfferingsRepository(api: api.client()));
  final host = _Host(api, c);
  await pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            key: const ValueKey('open'),
            onPressed: () async {
              host.results.add(
                await openMentoringComposer(
                  context,
                  controller: c,
                  pickFile: pickFile ?? ({required bool imageOnly}) async => _png(),
                  service: service?.call(c),
                  plan: plan?.call(c),
                  onOpenSettings: settingsLink ? () => host.settingsOpened++ : null,
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(c.start);
  await settle(tester);
  await tester.tap(find.byKey(const ValueKey('open')));
  await settle(tester);
  return host;
}

Finder _key(String k) => find.byKey(ValueKey(k));

String? _textOf(String key) => (find.byKey(ValueKey(key)).evaluate().single.widget as Text).data;

String _fieldText(WidgetTester tester, String key) => tester.widget<TextField>(_key(key)).controller!.text;

Future<void> _save(WidgetTester tester) async {
  await tester.tap(_key('composer-save'));
  await settle(tester);
}

Future<void> _unfocus(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.pump();
}

/// Picks a value from one of the hours / minutes dropdowns.
Future<void> _pick(WidgetTester tester, String key, String value) async {
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

Map<String, Object?> _programmeRow() =>
    planJson(
        'plan-programme',
        kind: 'CURRICULUM',
        title: 'Site to portfolio',
        blurb: 'A fixed run for the jump from a site to a portfolio.',
        price: 599900,
        compareAt: 899900,
        access: 3,
        sessionMin: 60,
        inclusions: ['Notes after every session'],
        modules: [
          moduleJson(1, 'Where you are', outline: 'Scope and gaps'),
          moduleJson(2, 'Vendor and SLA governance'),
          moduleJson(3, 'The portfolio business case', minutes: 90),
        ],
      )
      ..['modes'] = ['VIDEO', 'PHONE'];

void main() {
  setUpAll(loadAppFonts);
  setUp(() => mentoringNow = () => offeringsNow);

  group('the price rule on main: no ₹499 floor, but Paid means at least ₹1', () {
    test('a paid service or programme is any price from ₹1', () {
      expect(servicePriceProblem(free: false, price: '0', compareAt: ''), 'Priced services start at ₹1.');
      expect(servicePriceProblem(free: false, price: '1', compareAt: ''), isNull);
      expect(servicePriceProblem(free: false, price: '250', compareAt: ''), isNull);
      expect(servicePriceProblem(free: true, price: '0', compareAt: ''), isNull);
      expect(programmePriceProblem(free: false, price: '0', compareAt: ''), 'A paid programme is at least ₹1.');
      expect(programmePriceProblem(free: false, price: '1', compareAt: ''), isNull);
      expect(programmePriceProblem(free: false, price: '250', compareAt: ''), isNull);
    });
  });

  group('a new offering', () {
    testWidgets('starts as one session, with every section the website shows, and fits a 360 dp phone', (tester) async {
      await _open(tester, width: 360);
      expect(find.text('New 1:1 Mentoring'), findsOneWidget);
      expect(
        find.text('Offer a single session or a multi-session programme that mentees can request from your profile.'),
        findsOneWidget,
      );
      for (final s in ['overview', 'format', 'delivery', 'pricing', 'visibility']) {
        expect(_key('composer-$s'), findsOneWidget, reason: s);
      }
      expect(_key('composer-syllabus'), findsNothing, reason: 'one session has no syllabus');
      for (final t in ['Overview', 'Format', 'Delivery', 'Pricing', 'Visibility']) {
        expect(find.text(t), findsOneWidget);
      }
      expect(find.text('Title *'), findsOneWidget, reason: 'a red star: required');
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Cover Image'), findsOneWidget);
      expect(find.text('Number of Sessions'), findsOneWidget);
      expect(find.text('Session Length'), findsOneWidget);
      expect(find.text('Complete Within (Months)'), findsNothing);
      expect(_fieldText(tester, 'composer-count'), '1');
      expect(_textOf('composer-count-note'), '1 for a single session; 2–24 for a programme.');
      // Delivery: the ways the mentor meets in Settings, all picked = every way.
      expect(find.text('Meeting Format'), findsOneWidget);
      expect(_key('composer-mode-VIDEO'), findsOneWidget);
      expect(_key('composer-mode-PHONE'), findsOneWidget);
      expect(_key('composer-mode-IN_PERSON'), findsNothing, reason: 'not a way this mentor meets');
      expect(find.text('Video Call'), findsOneWidget);
      expect(_textOf('composer-modes-note'), 'Available meeting formats.');
      expect(find.text('Manage in Settings'), findsOneWidget);
      expect(find.text('Change in Settings'), findsOneWidget);
      expect(find.textContaining('No weekly hours set. Mentees can still request; you set each time.'), findsOneWidget);
      // Pricing: Paid, with no price suggested and no criteria line.
      expect(find.text('GST will be added at checkout.'), findsOneWidget);
      expect(find.text('Price (₹)'), findsOneWidget);
      expect(_fieldText(tester, 'composer-price'), '');
      expect(find.text('Compare-at Price'), findsOneWidget);
      expect(find.text('Displayed as a strikethrough price. Discounts cannot exceed 50%.'), findsOneWidget);
      expect(find.textContaining('Minimum'), findsNothing);
      // Visibility: published.
      expect(find.text('Published and visible on your profile.'), findsOneWidget);
      expect(find.text('Save Session'), findsOneWidget);
      expect(_textOf('composer-blocker'), 'Enter a title (at least 4 characters).');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Save sends the ONE_ON_ONE body the website sends, and closes saved', (tester) async {
      final h = await _open(tester);
      await typeKey(tester, 'composer-title', 'abc');
      expect(find.text('At least 4 characters.'), findsOneWidget);
      await typeKey(tester, 'composer-title', 'CV review and next-role plan');
      expect(find.text('At least 4 characters.'), findsNothing);
      expect(_textOf('composer-blocker'), 'A paid session is at least ₹1.');
      await typeKey(tester, 'composer-description', 'Your CV, read line by line.');
      await typeKey(tester, 'composer-price', '1499');
      await _pick(tester, 'composer-length-minutes', '30');
      expect(_key('composer-blocker'), findsNothing);
      await _save(tester);
      expect(h.api.bodyOf('POST /mentor-services/mine'), {
        'type': 'ONE_ON_ONE',
        'title': 'CV review and next-role plan',
        'blurb': 'Your CV, read line by line.',
        'coverUrl': null,
        'pricePaisa': 149900,
        'compareAtPaisa': null,
        'durationMin': 90,
        'active': true,
        'modes': <String>[],
        'location': null,
        'locationLat': null,
        'locationLng': null,
      });
      expect(h.api.count('POST /mentor-plans'), 0);
      expect(h.results, [true]);
      expect(h.controller.singles.map((s) => s.title), contains('CV review and next-role plan'));
    });

    testWidgets('raising the count to 3 brings the syllabus, carries the fields, and saves a CURRICULUM programme', (
      tester,
    ) async {
      final h = await _open(tester);
      await typeKey(tester, 'composer-title', 'Site to portfolio');
      await typeKey(tester, 'composer-price', '1499');
      await _pick(tester, 'composer-length-minutes', '30');
      await typeKey(tester, 'composer-count', '3');

      expect(_key('composer-syllabus'), findsOneWidget);
      expect(find.text('Syllabus'), findsOneWidget);
      expect(_textOf('composer-syllabus-count'), '3 of 24');
      for (var i = 0; i < 3; i++) {
        expect(_key('composer-row-title-$i'), findsOneWidget);
      }
      expect(find.text('Session Title'), findsNWidgets(3));
      expect(find.text('Topics Covered'), findsNWidgets(3));
      expect(find.text('Save Programme'), findsOneWidget);
      expect(find.text('Programme Price (₹)'), findsOneWidget);
      expect(find.text('Charged once, on acceptance. GST is added at checkout.'), findsOneWidget);
      expect(find.text('Applied to every session; adjust any session below.'), findsOneWidget);
      expect(_fieldText(tester, 'composer-title'), 'Site to portfolio', reason: 'carried over');
      expect(_fieldText(tester, 'composer-price'), '1499', reason: 'carried over');
      expect(_fieldText(tester, 'composer-access'), '6');
      expect(_textOf('composer-blocker'), 'List at least 2 sessions.');

      await typeKey(tester, 'composer-row-title-0', 'Wh');
      expect(_textOf('composer-blocker'), 'Session 1 needs a title of at least 3 characters.');
      await typeKey(tester, 'composer-row-title-0', 'Where you are');
      await typeKey(tester, 'composer-row-topics-0', 'Scope and gaps');
      await typeKey(tester, 'composer-row-title-1', 'Vendor and SLA governance');
      await typeKey(tester, 'composer-row-title-2', 'The portfolio business case');
      await typeKey(tester, 'composer-access', '30');
      expect(_textOf('composer-blocker'), 'Set "Complete Within" to 1–24 months.');
      await typeKey(tester, 'composer-access', '4');
      await typeKey(tester, 'composer-included', 'Notes after every session\n\nA CV review');
      expect(_key('composer-blocker'), findsNothing);
      await _save(tester);

      expect(h.api.count('POST /mentor-services/mine'), 0);
      expect(h.api.bodyOf('POST /mentor-plans'), {
        'title': 'Site to portfolio',
        'coverUrl': null,
        'pricePaisa': 149900,
        'compareAtPaisa': null,
        'sessionDurationMin': 90,
        'inclusions': ['Notes after every session', 'A CV review'],
        'active': true,
        'kind': 'CURRICULUM',
        'modes': <String>[],
        'location': null,
        'locationLat': null,
        'locationLng': null,
        'accessMonths': 4,
        'modules': [
          {'title': 'Where you are', 'outline': 'Scope and gaps', 'durationMin': 90},
          {'title': 'Vendor and SLA governance', 'durationMin': 90},
          {'title': 'The portfolio business case', 'durationMin': 90},
        ],
      });
      expect(h.results, [true]);
      expect(h.controller.programmes.map((p) => p.steps.length), contains(3));
    });

    testWidgets('a half-typed 1 waits for the field to lose focus; 25 is held to 24 once it does', (tester) async {
      await _open(tester);
      await typeKey(tester, 'composer-title', 'Leadership run');
      await typeKey(tester, 'composer-count', '3');
      expect(_key('composer-syllabus'), findsOneWidget);

      await typeKey(tester, 'composer-count', '1');
      expect(_key('composer-syllabus'), findsOneWidget, reason: 'a "1" on the way to "12" changes nothing yet');
      await typeKey(tester, 'composer-count', '12');
      expect(_textOf('composer-syllabus-count'), '12 of 24');
      expect(_key('composer-row-title-11'), findsOneWidget);

      await typeKey(tester, 'composer-count', '1');
      await _unfocus(tester);
      expect(_key('composer-syllabus'), findsNothing, reason: 'one, once the field lets go');
      expect(find.text('Save Session'), findsOneWidget);
      expect(_fieldText(tester, 'composer-title'), 'Leadership run', reason: 'carried back');
      expect(_fieldText(tester, 'composer-count'), '1');

      await typeKey(tester, 'composer-count', '25');
      expect(_key('composer-syllabus'), findsNothing, reason: 'over the top waits too');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(_fieldText(tester, 'composer-count'), '24');
      expect(_textOf('composer-syllabus-count'), '24 of 24');
      expect(tester.widget<TextButton>(_key('composer-add-session')).onPressed, isNull, reason: '24 is the most');
    });

    testWidgets('a smaller count drops rows from the end, with an Undo when typed rows are cut', (tester) async {
      await _open(tester);
      await typeKey(tester, 'composer-count', '4');
      await typeKey(tester, 'composer-row-title-2', 'Third session');
      await typeKey(tester, 'composer-row-topics-3', 'Fourth topics');
      await typeKey(tester, 'composer-count', '2');
      expect(_key('composer-row-title-2'), findsNothing);
      expect(find.text('Removed 2 sessions, 2 with details entered.'), findsOneWidget);
      await tapKey(tester, 'composer-dropped-undo');
      expect(_key('composer-dropped'), findsNothing);
      expect(_fieldText(tester, 'composer-row-title-2'), 'Third session');
      expect(_fieldText(tester, 'composer-row-topics-3'), 'Fourth topics');
      expect(_fieldText(tester, 'composer-count'), '4', reason: 'the count follows the rows');

      // Blank rows go without a word.
      await typeKey(tester, 'composer-count', '5');
      await typeKey(tester, 'composer-count', '4');
      expect(_key('composer-dropped'), findsNothing);

      // Add and Remove move the count too.
      await tapKey(tester, 'composer-add-session');
      expect(_fieldText(tester, 'composer-count'), '5');
      await tapKey(tester, 'composer-row-remove-0');
      expect(_fieldText(tester, 'composer-count'), '4');
      expect(_fieldText(tester, 'composer-row-title-1'), 'Third session', reason: 'the rows below move up');
    });

    testWidgets('free sends price 0 and no compare-at; Paid with no price says so, and Save sends nothing', (tester) async {
      final h = await _open(tester);
      await typeKey(tester, 'composer-title', 'Free intro call');
      expect(_textOf('composer-blocker'), 'A paid session is at least ₹1.');
      await _save(tester);
      expect(h.api.count('POST /mentor-services/mine'), 0);
      expect(
        (find.byKey(const ValueKey('composer-problem')).evaluate().single.widget as Text).data,
        'A paid session is at least ₹1.',
        reason: 'tapping Save says what blocks it',
      );
      await typeKey(tester, 'composer-compare-at', '999');
      await tapKey(tester, 'composer-pricing-free');
      expect(find.text('One free session per mentee.'), findsOneWidget);
      expect(_key('composer-price'), findsNothing);
      expect(_key('composer-problem'), findsNothing, reason: 'nothing blocks it any more');
      await _save(tester);
      expect(h.api.bodyOf('POST /mentor-services/mine'), {
        'type': 'ONE_ON_ONE',
        'title': 'Free intro call',
        'coverUrl': null,
        'pricePaisa': 0,
        'compareAtPaisa': null,
        'durationMin': 60,
        'active': true,
        'modes': <String>[],
        'location': null,
        'locationLat': null,
        'locationLng': null,
      });
    });

    testWidgets('the compare-at price must be higher than the price and at most 50% off it', (tester) async {
      final h = await _open(tester);
      await typeKey(tester, 'composer-title', 'Strategy session');
      await typeKey(tester, 'composer-price', '1000');
      await typeKey(tester, 'composer-compare-at', '1000');
      expect(find.text('Compare-at price must exceed the price.'), findsNWidgets(2), reason: 'under the field and below');
      await typeKey(tester, 'composer-compare-at', '2500');
      expect(find.text('Discount cannot exceed 50%.'), findsNWidgets(2));
      await typeKey(tester, 'composer-compare-at', '2000');
      expect(_key('composer-blocker'), findsNothing);
      await tapKey(tester, 'composer-published');
      expect(find.text('Draft. Hidden from your profile.'), findsOneWidget);
      await _save(tester);
      final body = h.api.bodyOf('POST /mentor-services/mine')! as Map;
      expect(body['pricePaisa'], 100000);
      expect(body['compareAtPaisa'], 200000);
      expect(body['active'], false);
    });

    testWidgets('the listing cap (10, drafts included) blocks a new single session, never a programme', (tester) async {
      final h = await _open(
        tester,
        world: OfferingsWorld(services: [for (var i = 0; i < 10; i++) serviceJson('svc-$i', title: 'Listing $i')]),
      );
      await typeKey(tester, 'composer-title', 'One more call');
      await typeKey(tester, 'composer-price', '999');
      expect(_textOf('composer-blocker'), 'Listing limit reached (10). Retire a single session to add another.');
      await _save(tester);
      expect(h.api.count('POST /mentor-services/mine'), 0);
      await typeKey(tester, 'composer-count', '2');
      expect(_textOf('composer-blocker'), 'List at least 2 sessions.', reason: 'a programme is not a listing');
    });

    testWidgets('a refusal keeps the page open with what was typed and the API\'s sentence', (tester) async {
      final h = await _open(
        tester,
        extra: {'POST /mentor-services/mine': (_) => refuse('You can list up to 10 services — retire one first.')},
      );
      await typeKey(tester, 'composer-title', 'Career clarity call');
      await typeKey(tester, 'composer-price', '799');
      await _save(tester);
      expect(h.api.count('POST /mentor-services/mine'), 1);
      expect(find.text('You can list up to 10 services — retire one first.'), findsOneWidget);
      expect(find.text('New 1:1 Mentoring'), findsOneWidget, reason: 'still open');
      expect(_fieldText(tester, 'composer-title'), 'Career clarity call');
      expect(_fieldText(tester, 'composer-price'), '799');
      expect(h.results, isEmpty);
    });

    testWidgets('in person needs a venue, sent as a line with no pin; no way picked says so', (tester) async {
      final h = await _open(tester, me: mentorMe(modes: ['VIDEO', 'IN_PERSON']));
      await typeKey(tester, 'composer-title', 'Site walk-through');
      await tapKey(tester, 'composer-pricing-free');
      expect(_key('composer-venue'), findsOneWidget, reason: 'every way includes in person');
      await tapKey(tester, 'composer-mode-VIDEO');
      expect(_textOf('composer-modes-note'), 'Mentees can request only the selected formats.');
      expect(_textOf('composer-blocker'), 'Add the venue for in-person sessions.');
      await tapKey(tester, 'composer-mode-IN_PERSON');
      expect(_textOf('composer-modes-note'), 'Select at least one format.');
      expect(_textOf('composer-blocker'), 'Select at least one format.');
      expect(_key('composer-venue'), findsNothing);
      await tapKey(tester, 'composer-mode-IN_PERSON');
      await typeKey(tester, 'composer-venue', 'ICR Bengaluru, 4th floor training room');
      await _save(tester);
      final body = h.api.bodyOf('POST /mentor-services/mine')! as Map;
      expect(body['modes'], ['IN_PERSON']);
      expect(body['location'], 'ICR Bengaluru, 4th floor training room');
      expect(body['locationLat'], isNull);
      expect(body['locationLng'], isNull);
    });

    testWidgets('a cover is uploaded for mentor-offering and sent; one over 2 MB is refused before it is sent', (
      tester,
    ) async {
      var big = false;
      final h = await _open(tester, pickFile: ({required bool imageOnly}) async => _png(bytes: big ? 3 << 20 : 2048));
      await typeKey(tester, 'composer-title', 'Portfolio review');
      await typeKey(tester, 'composer-price', '499');
      await tapKey(tester, 'composer-cover');
      expect(h.api.queryOf('POST /uploads'), {'purpose': 'mentor-offering'});
      expect(find.text('Replace Image'), findsOneWidget);
      big = true;
      await tapKey(tester, 'composer-cover');
      expect(find.text('That image is over 2MB. Compress it or choose a smaller one.'), findsOneWidget);
      expect(h.api.count('POST /uploads'), 1);
      await _save(tester);
      expect((h.api.bodyOf('POST /mentor-services/mine')! as Map)['coverUrl'], '/uploads/mentor-offering-stored.pdf');
    });

    testWidgets('Manage in Settings closes the composer and opens Settings; the weekly hours read as the website\'s', (
      tester,
    ) async {
      final h = await _open(
        tester,
        me: mentorMe(
          blocks: [
            {'weekday': 1, 'startMin': 1080, 'endMin': 1200},
            {'weekday': 1, 'startMin': 600, 'endMin': 660},
            {'weekday': 3, 'startMin': 1080, 'endMin': 1200},
          ],
        ),
      );
      expect(find.textContaining('2 days per week · Asia/Kolkata'), findsOneWidget);
      await tapKey(tester, 'composer-manage-settings');
      expect(h.results, [false]);
      expect(h.settingsOpened, 1);
      expect(find.text('New 1:1 Mentoring'), findsNothing);
    });

    testWidgets('without a Settings handler the two links are not drawn', (tester) async {
      await _open(tester, settingsLink: false);
      expect(find.text('Meeting Format'), findsOneWidget);
      expect(find.text('Manage in Settings'), findsNothing);
      expect(find.text('Change in Settings'), findsNothing);
    });

    testWidgets('while the mentor\'s formats cannot be read, a save leaves "where" out (the API keeps it)', (
      tester,
    ) async {
      final h = await _open(tester, extra: {'GET /mentorship/mentors/me': (_) => refuse('Not now', status: 503)});
      expect(find.text('Unable to Load Your Meeting Formats'), findsOneWidget);
      await typeKey(tester, 'composer-title', 'Career clarity call');
      await typeKey(tester, 'composer-price', '799');
      await _save(tester);
      final body = h.api.bodyOf('POST /mentor-services/mine')! as Map;
      expect(body.containsKey('modes'), isFalse);
      expect(body.containsKey('location'), isFalse);
    });
  });

  group('editing', () {
    testWidgets('a 1:1 session is held to one session, starts from what is held, and is saved in place', (tester) async {
      final world = OfferingsWorld(
        services: [
          for (var i = 0; i < 9; i++) serviceJson('svc-$i', title: 'Listing $i'),
          serviceJson(
            'svc-strategy',
            title: 'Strategy session',
            price: 149900,
            compareAt: 199900,
            duration: 45,
          )..['modes'] = ['VIDEO'],
        ],
      );
      final h = await _open(tester, world: world, service: (c) => c.singles.firstWhere((s) => s.id == 'svc-strategy'));
      expect(find.text('Edit 1:1 Mentoring'), findsOneWidget);
      expect(find.text('Changes apply to new requests. Sessions already booked keep their terms.'), findsOneWidget);
      expect(tester.widget<TextField>(_key('composer-count')).enabled, isFalse);
      expect(_textOf('composer-count-note'), 'Saved as a single session. Create a new offering to sell several.');
      expect(_fieldText(tester, 'composer-title'), 'Strategy session');
      expect(_fieldText(tester, 'composer-description'), 'A call to map where you are.');
      expect(_fieldText(tester, 'composer-price'), '1499');
      expect(_fieldText(tester, 'composer-compare-at'), '1999');
      expect(_textOf('composer-modes-note'), 'Mentees can request only the selected formats.');
      expect(_key('composer-blocker'), findsNothing, reason: 'editing a listing never meets the cap');
      await typeKey(tester, 'composer-description', '');
      await _save(tester);
      expect(h.api.count('POST /mentor-services/mine'), 0);
      expect(h.api.bodyOf('PATCH /mentor-services/mine/svc-strategy'), {
        'type': 'ONE_ON_ONE',
        'title': 'Strategy session',
        'coverUrl': null,
        'pricePaisa': 149900,
        'compareAtPaisa': 199900,
        'durationMin': 45,
        'active': true,
        'modes': ['VIDEO'],
        'location': null,
        'locationLat': null,
        'locationLng': null,
      });
      expect(h.results, [true]);
    });

    testWidgets('a programme is held to 2–24 sessions, keeps its syllabus, and never sends its kind', (tester) async {
      final h = await _open(
        tester,
        world: OfferingsWorld(plans: [_programmeRow()]),
        plan: (c) => c.programmes.single,
      );
      expect(find.text('Edit 1:1 Mentoring'), findsOneWidget);
      expect(_textOf('composer-count-note'), 'Saved as a programme (2–24 sessions).');
      expect(_fieldText(tester, 'composer-count'), '3');
      expect(_fieldText(tester, 'composer-row-title-2'), 'The portfolio business case');
      expect(_fieldText(tester, 'composer-price'), '5999');
      expect(_fieldText(tester, 'composer-compare-at'), '8999');
      expect(_fieldText(tester, 'composer-access'), '3');
      expect(_fieldText(tester, 'composer-included'), 'Notes after every session');
      expect(find.text('Save Programme'), findsOneWidget);

      await typeKey(tester, 'composer-count', '1');
      await _unfocus(tester);
      expect(_fieldText(tester, 'composer-count'), '2', reason: 'a programme cannot become a single session');
      expect(_key('composer-syllabus'), findsOneWidget);
      expect(find.text('Removed 1 session, one with details entered.'), findsOneWidget);
      await tapKey(tester, 'composer-dropped-undo');
      expect(_fieldText(tester, 'composer-count'), '3');

      await typeKey(tester, 'composer-row-topics-1', 'SLAs that hold');
      await _save(tester);
      expect(h.api.count('POST /mentor-plans'), 0);
      expect(h.api.bodyOf('PATCH /mentor-plans/plan-programme'), {
        'title': 'Site to portfolio',
        'blurb': 'A fixed run for the jump from a site to a portfolio.',
        'coverUrl': null,
        'pricePaisa': 599900,
        'compareAtPaisa': 899900,
        'sessionDurationMin': 60,
        'inclusions': ['Notes after every session'],
        'active': true,
        'modes': <String>[],
        'location': null,
        'locationLat': null,
        'locationLng': null,
        'accessMonths': 3,
        'modules': [
          {'title': 'Where you are', 'outline': 'Scope and gaps', 'durationMin': 60},
          {'title': 'Vendor and SLA governance', 'outline': 'SLAs that hold', 'durationMin': 60},
          {'title': 'The portfolio business case', 'durationMin': 90},
        ],
      });
      expect(h.results, [true]);
    });

    testWidgets('an in-person programme keeps its map pin while the venue line is unchanged', (tester) async {
      final row = _programmeRow()
        ..['modes'] = ['IN_PERSON']
        ..['location'] = 'ICR Mumbai'
        ..['locationLat'] = 19.07
        ..['locationLng'] = 72.87;
      final h = await _open(
        tester,
        me: mentorMe(modes: ['VIDEO', 'IN_PERSON']),
        world: OfferingsWorld(plans: [row]),
        plan: (c) => c.programmes.single,
      );
      expect(_fieldText(tester, 'composer-venue'), 'ICR Mumbai');
      await _save(tester);
      var body = h.api.bodyOf('PATCH /mentor-plans/plan-programme')! as Map;
      expect(body['modes'], ['IN_PERSON']);
      expect([body['location'], body['locationLat'], body['locationLng']], ['ICR Mumbai', 19.07, 72.87]);

      await tester.tap(find.byKey(const ValueKey('open')));
      await settle(tester);
      await typeKey(tester, 'composer-venue', 'ICR Pune');
      await _save(tester);
      body = h.api.bodyOf('PATCH /mentor-plans/plan-programme')! as Map;
      expect([body['location'], body['locationLat'], body['locationLng']], ['ICR Pune', null, null]);
    });
  });
}
