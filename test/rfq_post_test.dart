import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/rfq/demo_rfq_repository.dart';
import 'package:icr_mobile/features/rfq/post_rfq_controller.dart';
import 'package:icr_mobile/features/rfq/post_rfq_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_detail_screen.dart';
import 'package:icr_mobile/features/rfq/rfq_links.dart';
import 'package:icr_mobile/features/rfq/rfq_models.dart';
import 'package:icr_mobile/features/rfq/rfq_rules.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';

import 'helpers/fonts.dart';
import 'rfq_fakes.dart';

/// Every control of the composer ("Post RFQ"), tapped: the kind, the details, the places, the service, the
/// description and its checklist, the line items, the files, the supplier criteria, the dates, who may reply, the
/// review, the send, the refusal that keeps what was typed, the draft, the edit and the copy. What the API does
/// with the body is proved in `test/live/rfq_live_test.dart`.
void main() {
  late FlakyRfqRepository repo;
  late RecordingRfqLinks links;
  final posted = <PostResult>[];

  setUpAll(loadAppFonts);
  setUp(() {
    RfqClock.now = () => DateTime.utc(2026, 10, 25, 9);
    repo = FlakyRfqRepository(now: RfqClock.now());
    links = RecordingRfqLinks();
    posted.clear();
  });
  tearDown(RfqClock.reset);

  /// A window tall enough to build the whole form, so every field can be found without scrolling.
  Future<void> open(
    WidgetTester tester, {
    String? editId,
    String? copyFrom,
    RfqKind? kind,
    VoidCallback? onCreateCompany,
    double height = 3600,
  }) async {
    tester.view.physicalSize = Size(390, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: PostRfqScreen(
          repository: repo,
          links: links,
          editRfqId: editId,
          copyFromRfqId: copyFrom,
          initialKind: kind,
          onPosted: posted.add,
          onCreateCompany: onCreateCompany,
        ),
      ),
    );
    await settle(tester, 8);
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> tapKey(WidgetTester tester, String k, {int frames = 8}) async {
    await tester.ensureVisible(key(k));
    await tester.tap(key(k));
    await settle(tester, frames);
  }

  Future<void> type(WidgetTester tester, String k, String text) async {
    await tester.enterText(key(k), text);
    await tester.pump();
  }

  Future<void> pickFrom(WidgetTester tester, String field, String option) async {
    await tapKey(tester, field, frames: 10);
    await tester.tap(find.text(option).last);
    await settle(tester, 10);
  }

  Future<void> addPlace(WidgetTester tester, String query, String label) async {
    await tapKey(tester, 'places-add', frames: 10);
    await tester.enterText(key('place-search'), query);
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    await tester.tap(key('place-option-$label'));
    await settle(tester);
    await tester.tap(key('place-done'));
    await settle(tester, 10);
  }

  /// What an enquiry needs to go live, besides the details the account already holds.
  Future<void> fillEnquiry(WidgetTester tester) async {
    await pickFrom(tester, 'facility-field', 'IT & ITES');
    await addPlace(tester, 'pun', 'Pune');
    await pickFrom(tester, 'category-field', 'Security Services');
    await type(tester, 'text', 'Round-the-clock guarding for our Pune campus, three shifts, about 600 staff.');
  }

  Future<void> send(WidgetTester tester) async {
    await tester.tap(key('send'));
    await settle(tester, 12);
  }

  testWidgets('opens on an enquiry, for the company, with the account\'s details filled in', (tester) async {
    await open(tester);
    expect(find.text('Post RFQ'), findsOneWidget);
    expect(find.text('Bharat Facilities'), findsOneWidget);
    expect(tester.widget<TextField>(key('contact-name')).controller!.text, 'Bharat Buyer');
    expect(tester.widget<TextField>(key('contact-phone')).controller!.text, '+919879879898');
    final email = tester.widget<TextField>(key('contact-email'));
    expect(email.controller!.text, 'buyer@icr.dev');
    expect(email.readOnly, isTrue, reason: 'the account\'s address is not editable here');
    expect(find.text('Quick supplier matching'), findsOneWidget);
    expect(find.text('Formal quotation process'), findsOneWidget);
    expect(
      find.text('Supplier criteria'),
      findsNothing,
      reason: 'the RFQ\'s own sections join only when RFQ is chosen',
    );
    expect(find.text('Send enquiry'), findsOneWidget);
    expect(find.text('Save draft'), findsOneWidget);
  });

  testWidgets('choosing RFQ adds its criteria and deadlines and keeps what was typed', (tester) async {
    await open(tester);
    await type(tester, 'text', 'Housekeeping for a 12-acre campus, daily, from 1 December.');
    await tapKey(tester, 'kind-rfq');
    expect(find.text('Supplier criteria'), findsWidgets);
    expect(find.text('Pre-qualification deadline'), findsWidgets);
    expect(find.text('Quote deadline'), findsOneWidget);
    expect(find.text('Create RFQ'), findsOneWidget);
    expect(find.text('Scope of services'), findsOneWidget);
    expect(tester.widget<TextField>(key('text')).controller!.text, startsWith('Housekeeping'));
    await tapKey(tester, 'kind-enquiry');
    expect(find.text('Send enquiry'), findsOneWidget);
    expect(find.text('Who can reply'), findsOneWidget);
    expect(tester.widget<TextField>(key('text')).controller!.text, startsWith('Housekeeping'));
  });

  testWidgets('sending an empty form lists what to fix, goes to it, and sends nothing', (tester) async {
    await open(tester);
    await send(tester);
    expect(find.byKey(const ValueKey('problems')), findsOneWidget);
    expect(find.text('3 things to fix before sending'), findsNothing, reason: 'more than three are missing');
    for (final field in ['facilityType', 'locations', 'category', 'text']) {
      expect(key('problem-$field'), findsOneWidget, reason: field);
    }
    expect(find.text('Select a facility type'), findsWidgets);
    expect(find.text('Pick at least one place'), findsWidgets);
    expect(find.text('Select a service category'), findsWidgets);
    expect(find.text('Describe what you need'), findsWidgets);
    expect(repo.created, isEmpty);
    expect(repo.calls, isNot(contains('create')));
    // A problem line is a link to its section; fixing the field takes it off the list.
    await pickFrom(tester, 'facility-field', 'IT & ITES');
    expect(key('problem-facilityType'), findsNothing);
  });

  group('the details', () {
    testWidgets('a phone of the wrong shape and a long contact name are refused as the API refuses them', (
      tester,
    ) async {
      await open(tester);
      await type(tester, 'contact-phone', '12345');
      await send(tester);
      expect(find.text('Enter a phone number of 10 to 15 digits'), findsWidgets);
      await type(tester, 'contact-phone', '');
      await type(tester, 'contact-name', '');
      await send(tester);
      expect(find.text('Enter a phone number'), findsWidgets);
      expect(find.text('Enter the contact person'), findsWidgets);
    });
  });

  group('the places', () {
    testWidgets('a search finds places with their state and country, and a tap adds one', (tester) async {
      await open(tester);
      await tapKey(tester, 'places-add', frames: 10);
      await tester.enterText(key('place-search'), 'dub');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(find.text('Dubai, United Arab Emirates'), findsOneWidget);
      await tester.tap(key('place-option-Dubai, United Arab Emirates'));
      await settle(tester);
      await tester.tap(key('place-done'));
      await settle(tester, 10);
      expect(key('place-chip-Dubai, United Arab Emirates'), findsOneWidget);
    });

    testWidgets('what was typed can be added as it stands, and a place is removed with its cross', (tester) async {
      await open(tester);
      await tapKey(tester, 'places-add', frames: 10);
      await tester.enterText(key('place-search'), 'Khopoli');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(key('place-typed'), findsOneWidget);
      await tester.tap(key('place-typed'));
      await settle(tester);
      await tester.tap(key('place-done'));
      await settle(tester, 10);
      expect(key('place-chip-Khopoli'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove Khopoli'));
      await settle(tester);
      expect(key('place-chip-Khopoli'), findsNothing);
    });

    testWidgets('a failed search says so and still lets the typed name in', (tester) async {
      repo.failPlaceSearch = true;
      await open(tester);
      await tapKey(tester, 'places-add', frames: 10);
      await tester.enterText(key('place-search'), 'Pune');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(find.textContaining('not available right now'), findsOneWidget);
      expect(key('place-typed'), findsOneWidget);
    });

    testWidgets('at most ten places', (tester) async {
      await open(tester);
      final c = PostRfqController(repository: repo);
      for (var i = 0; i < 10; i++) {
        expect(c.addPlace(RfqPlace.typed('City $i')), isTrue);
      }
      expect(c.canAddPlace, isFalse);
      expect(c.addPlace(RfqPlace.typed('One more')), isFalse);
      expect(c.addPlace(RfqPlace.typed('city 3')), isTrue, reason: 'the same name again is not a new place');
      expect(c.draft.places, hasLength(10));
      expect(
        c.draft.problems(goingLive: true, askCompany: false, effectiveTitle: 't').containsKey('locations'),
        isFalse,
      );
    });
  });

  group('the service', () {
    testWidgets('a category opens its sub-categories, and a sub-category its specialisations', (tester) async {
      await open(tester);
      expect(key('subcategory-field'), findsNothing);
      await pickFrom(tester, 'category-field', 'Security Services');
      expect(key('subcategory-field'), findsOneWidget);
      expect(key('specialisation-field'), findsNothing);
      await pickFrom(tester, 'subcategory-field', 'Physical Security');
      await settle(tester, 8);
      expect(key('specialisation-field'), findsOneWidget);
      await pickFrom(tester, 'specialisation-field', 'Manned Guarding');
      await settle(tester, 10);
      expect(find.descendant(of: key('specialisation-field'), matching: find.text('Manned Guarding')), findsOneWidget);
      // Changing the category starts the levels below again.
      await pickFrom(tester, 'category-field', 'Engineering Services');
      expect(key('specialisation-field'), findsNothing);
      expect(find.text('Physical Security'), findsNothing);
    });

    testWidgets('the title follows the service until one is typed', (tester) async {
      await open(tester);
      await pickFrom(tester, 'facility-field', 'IT & ITES');
      await pickFrom(tester, 'category-field', 'Security Services');
      expect(find.textContaining('Left blank it reads "IT & ITES — Security Services"'), findsOneWidget);
      await type(tester, 'title', 'Guarding for Pune');
      expect(find.textContaining('Left blank it reads'), findsOneWidget);
      await tapKey(tester, 'kind-rfq');
      expect(find.textContaining('Bharat Facilities — Security Services RFQ'), findsWidgets);
    });
  });

  group('the description', () {
    testWidgets('the checklist ticks what the text already says and adds a labelled line for the rest', (tester) async {
      await open(tester);
      expect(find.text('0 of 6 covered'), findsOneWidget);
      await tapKey(tester, 'check-add-frequency');
      expect(tester.widget<TextField>(key('text')).controller!.text, 'Frequency: ');
      expect(find.text('0 of 6 covered'), findsOneWidget, reason: 'an empty prompt line does not tick its own item');
      await type(tester, 'text', 'Frequency: daily, 24x7 across 3 sites');
      expect(find.text('3 of 6 covered'), findsOneWidget);
      await tapKey(tester, 'check-add-start');
      expect(
        tester.widget<TextField>(key('text')).controller!.text,
        'Frequency: daily, 24x7 across 3 sites\nStart date: ',
      );
    });

    testWidgets('a prompt line nobody answered is not sent', (tester) async {
      await open(tester);
      await fillEnquiry(tester);
      await tapKey(tester, 'check-add-start');
      await send(tester);
      await tester.tap(key('review-confirm'));
      await settle(tester, 12);
      expect(repo.created.single['description'], isNot(contains('Start date')));
    });

    testWidgets('too short a description is refused with the count, and the API\'s limit is shown', (tester) async {
      await open(tester);
      await type(tester, 'text', 'Guards please');
      await send(tester);
      expect(find.textContaining('at least 20 characters'), findsWidgets);
    });

    testWidgets('a budget is a rupee amount', (tester) async {
      await open(tester);
      await type(tester, 'budget', 'lots');
      await send(tester);
      expect(find.text('Enter an amount in rupees, like 50,00,000'), findsWidgets);
      await type(tester, 'budget', '12,00,000');
      await send(tester);
      expect(find.text('Enter an amount in rupees, like 50,00,000'), findsNothing);
    });
  });

  group('the line items', () {
    testWidgets('an item is added, changed and removed', (tester) async {
      await open(tester);
      await tapKey(tester, 'item-add', frames: 10);
      await tester.enterText(key('item-name'), 'Floor scrubber machine');
      await tester.enterText(key('item-quantity'), '2');
      await tester.enterText(key('item-unit'), 'units');
      await tester.tap(key('item-save'));
      await settle(tester, 10);
      expect(find.text('Floor scrubber machine'), findsOneWidget);
      expect(find.text('2 units'), findsOneWidget);
      await tester.tap(find.text('Floor scrubber machine'));
      await settle(tester, 10);
      await tester.enterText(key('item-quantity'), '5');
      await tester.tap(key('item-save'));
      await settle(tester, 10);
      expect(find.text('5 units'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove Floor scrubber machine'));
      await settle(tester);
      expect(key('item-row-0'), findsNothing);
    });

    testWidgets('a nameless item and a quantity that is not a whole number are refused in the sheet', (tester) async {
      await open(tester);
      await tapKey(tester, 'item-add', frames: 10);
      await tester.tap(key('item-save'));
      await settle(tester);
      expect(find.text('Name the item'), findsOneWidget);
      await tester.enterText(key('item-name'), 'Mop');
      await tester.enterText(key('item-quantity'), '2.5');
      await tester.tap(key('item-save'));
      await settle(tester);
      expect(find.text('Quantity must be a whole number'), findsOneWidget);
      await tester.enterText(key('item-quantity'), '0');
      await tester.tap(key('item-save'));
      await settle(tester);
      expect(find.textContaining('Quantity must be 1 to'), findsOneWidget);
    });
  });

  group('the files', () {
    PickedRfqFile pdf(String name, {int size = 2048}) => PickedRfqFile(name: name, bytes: List.filled(size, 1));

    testWidgets('a file goes up as it is chosen and comes back with a title to start from', (tester) async {
      links.toPick = [pdf('site-layout-v2.pdf')];
      await open(tester);
      await tapKey(tester, 'attach-add');
      expect(repo.calls, contains('uploadFile'));
      expect(key('file-row-0'), findsOneWidget);
      expect(tester.widget<TextField>(key('file-title-0')).controller!.text, 'site-layout-v2');
      expect(find.textContaining('site-layout-v2.pdf'), findsOneWidget);
    });

    testWidgets('the title is the buyer\'s own words, and a file with none is refused', (tester) async {
      links.toPick = [pdf('IMG_4821.pdf')];
      await open(tester);
      await tapKey(tester, 'attach-add');
      await type(tester, 'file-title-0', 'Site layout, ground floor');
      expect(repo.created, isEmpty);
      await type(tester, 'file-title-0', '');
      expect(find.text('Give this file a title'), findsOneWidget);
      await send(tester);
      expect(find.text('Give every file a title'), findsWidgets);
    });

    testWidgets('a wrong type and a file over 10 MB are turned away with the reason, without a trip to the API', (
      tester,
    ) async {
      links.toPick = [
        const PickedRfqFile(name: 'virus.exe', bytes: [1, 2, 3]),
        pdf('huge.pdf', size: 11 * 1024 * 1024),
        pdf('fine.pdf'),
      ];
      await open(tester);
      await tapKey(tester, 'attach-add');
      expect(find.textContaining('virus.exe is not a PDF'), findsOneWidget);
      expect(find.textContaining('huge.pdf is over 10 MB'), findsOneWidget);
      expect(repo.uploads.map((f) => f.name), ['fine.pdf']);
    });

    testWidgets('a refused upload stays with its sentence and Retry sends it again', (tester) async {
      links.toPick = [pdf('plan.pdf')];
      repo.refuseNextUpload = 'application/x-foo is not an accepted file type for this upload.';
      await open(tester);
      await tapKey(tester, 'attach-add');
      expect(find.textContaining('is not an accepted file type'), findsOneWidget);
      expect(key('file-row-0'), findsNothing);
      await tester.tap(key('upload-retry-plan.pdf'));
      await settle(tester, 10);
      expect(key('file-row-0'), findsOneWidget);
      expect(key('upload-plan.pdf'), findsNothing);
    });

    testWidgets('a file is removed with its bin, and at most ten fit', (tester) async {
      links.toPick = [pdf('a.pdf'), pdf('b.pdf')];
      await open(tester);
      await tapKey(tester, 'attach-add');
      await tester.tap(key('file-remove-0'));
      await settle(tester);
      expect(key('file-row-1'), findsNothing);
      expect(tester.widget<TextField>(key('file-title-0')).controller!.text, 'b');

      final c = PostRfqController(repository: repo);
      await c.addFiles([for (var i = 0; i < 12; i++) pdf('f$i.pdf')]);
      expect(c.draft.attachments, hasLength(10));
      expect(c.uploadNotice, contains('Only 10 more files fit'));
      await c.addFiles([pdf('one-more.pdf')]);
      expect(c.uploadNotice, contains('the most (10) files'));
    });

    testWidgets('the files are sent with the post as titled uploads', (tester) async {
      links.toPick = [pdf('site-layout.pdf')];
      await open(tester);
      await fillEnquiry(tester);
      await tapKey(tester, 'attach-add');
      await type(tester, 'file-title-0', 'Site layout, ground floor');
      await send(tester);
      await tester.tap(key('review-confirm'));
      await settle(tester, 12);
      final files = repo.created.single['attachments'] as List;
      expect(files, hasLength(1));
      expect((files.single as Map)['title'], 'Site layout, ground floor');
      expect((files.single as Map)['url'], startsWith('/uploads/'));
    });

    testWidgets('while a file is still going up the post waits', (tester) async {
      await tester.runAsync(() async {
        final c = PostRfqController(repository: _SlowUpload());
        await c.start();
        final done = c.addFiles([pdf('slow.pdf')]);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(c.uploading, isTrue);
        expect(await c.submit(publish: true), isFalse, reason: 'it would go without the file');
        await done;
        expect(c.uploading, isFalse);
      });
    });
  });

  test('leaving the form while the pickers still load does not notify a disposed controller', () async {
    final slow = _SlowCategories();
    final c = PostRfqController(repository: slow);
    final started = c.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    c.dispose();
    slow.gate.complete();
    // Without the guard this throws "A PostRfqController was used after being disposed".
    await started;
  });

  group('an RFQ', () {
    testWidgets('its criteria open, are counted, and a compliance item toggles', (tester) async {
      await open(tester, kind: RfqKind.rfq);
      expect(find.text('Add supplier criteria'), findsOneWidget);
      await tapKey(tester, 'criteria-toggle');
      await type(tester, 'min-years', '5');
      await type(tester, 'min-turnover', '5000000');
      await tapKey(tester, 'compliance-GST');
      await tapKey(tester, 'compliance-PF');
      await tapKey(tester, 'presence-PAN_INDIA');
      await pickFrom(tester, 'min-employees', '201-500 employees');
      await tapKey(tester, 'criteria-toggle');
      expect(find.text('5 criteria set: edit'), findsOneWidget);
      await tapKey(tester, 'criteria-toggle');
      await tapKey(tester, 'presence-PAN_INDIA');
      await tapKey(tester, 'criteria-toggle');
      expect(find.text('4 criteria set: edit'), findsOneWidget, reason: 'tapping a chosen presence takes it off');
    });

    testWidgets('the last 3 years cannot be less than one year, and years are whole', (tester) async {
      await open(tester, kind: RfqKind.rfq);
      await tapKey(tester, 'criteria-toggle');
      await type(tester, 'min-years', '5.5');
      await type(tester, 'min-turnover', '5000000');
      await type(tester, 'min-turnover-3', '4000000');
      await send(tester);
      expect(find.text('Use a whole number of years'), findsOneWidget);
      expect(find.text("The last 3 years' turnover cannot be less than one year's"), findsOneWidget);
    });

    testWidgets('the two deadlines are picked from the calendar, and the quote deadline must follow', (tester) async {
      await open(tester, kind: RfqKind.rfq);
      await send(tester);
      expect(find.text('Set a pre-qualification deadline'), findsWidgets);
      expect(find.text('Set a quote deadline'), findsWidgets);
      await tapKey(tester, 'prequal-date');
      await tester.tap(find.text('28'));
      await tester.tap(find.text('OK'));
      await settle(tester, 10);
      expect(find.text('28 Oct 2026'), findsOneWidget);
      await tapKey(tester, 'due-date');
      await tester.tap(find.text('31'));
      await tester.tap(find.text('OK'));
      await settle(tester, 10);
      expect(find.text('31 Oct 2026'), findsOneWidget);
      // A later pre-qualification date clears a quote date that no longer follows it.
      await tapKey(tester, 'prequal-date');
      await tester.tap(find.text('31'));
      await tester.tap(find.text('OK'));
      await settle(tester, 10);
      expect(find.text('31 Oct 2026'), findsOneWidget);
      expect(find.text('Pick a date'), findsOneWidget, reason: 'the quote deadline went with it');
    });

    testWidgets('a complete RFQ is sent with its scope, criteria and deadlines as the API takes them', (tester) async {
      await open(tester, kind: RfqKind.rfq);
      await fillEnquiry(tester);
      await tapKey(tester, 'criteria-toggle');
      await type(tester, 'min-years', '5');
      await tapKey(tester, 'compliance-GST');
      await tapKey(tester, 'prequal-date');
      await tester.tap(find.text('28'));
      await tester.tap(find.text('OK'));
      await settle(tester, 10);
      await tapKey(tester, 'due-date');
      await tester.tap(find.text('31'));
      await tester.tap(find.text('OK'));
      await settle(tester, 10);
      await send(tester);
      expect(find.text('Review your RFQ'), findsOneWidget);
      expect(find.text('Pre-qualification until 28 Oct 2026 · quotes by 31 Oct 2026'), findsOneWidget);
      await tester.tap(key('review-confirm'));
      await settle(tester, 12);
      final body = repo.created.single;
      expect(body['kind'], 'RFQ');
      expect(body['status'], 'PUBLISHED');
      expect(body['visibility'], 'PUBLIC');
      expect(body['scope'], startsWith('Round-the-clock'));
      expect(body.containsKey('description'), isFalse, reason: 'the API copies an RFQ\'s scope into its description');
      expect(body['minYearsInBusiness'], 5);
      expect(body['statutoryCompliance'], ['GST']);
      expect(body['preQualEndDate'], '2026-10-28T18:29:59.999Z');
      expect(body['dueDate'], '2026-10-31T18:29:59.999Z');
      expect(body['title'], 'Bharat Facilities — Security Services RFQ');
    });
  });

  group('who can reply', () {
    testWidgets('an invite-only enquiry needs suppliers, and goes to them as a private requirement', (tester) async {
      await open(tester);
      await fillEnquiry(tester);
      await tapKey(tester, 'audience-invited');
      await send(tester);
      expect(find.text('Choose at least one supplier to invite'), findsWidgets);
      expect(repo.created, isEmpty);
      await tapKey(tester, 'invite-choose', frames: 12);
      await tester.tap(key('supplier-demo-v-bluedot'));
      await settle(tester);
      await tester.tap(key('supplier-demo-v-innowork'));
      await settle(tester);
      await tester.tap(key('supplier-confirm'));
      await settle(tester, 12);
      expect(key('invited-demo-v-bluedot'), findsOneWidget);
      expect(key('invited-demo-v-innowork'), findsOneWidget);
      await send(tester);
      expect(find.text('Only the suppliers you chose are told, and only they can reply.'), findsOneWidget);
      await tester.tap(key('review-confirm'));
      await settle(tester, 12);
      final body = repo.created.single;
      expect(body['visibility'], 'TARGETED');
      expect(body['vendorIds'], ['demo-v-bluedot', 'demo-v-innowork']);
      expect(body['status'], 'PUBLISHED');
    });

    testWidgets('a chosen supplier is taken off with its cross, and an RFQ offers no invite-only choice', (
      tester,
    ) async {
      await open(tester);
      await tapKey(tester, 'audience-invited');
      await tapKey(tester, 'invite-choose', frames: 12);
      await tester.tap(key('supplier-demo-v-bluedot'));
      await settle(tester);
      await tester.tap(key('supplier-confirm'));
      await settle(tester, 12);
      await tester.tap(find.byTooltip('Remove BlueDot'));
      await settle(tester);
      expect(key('invited-demo-v-bluedot'), findsNothing);
      await tapKey(tester, 'kind-rfq');
      expect(key('audience-invited'), findsNothing);
    });
  });

  group('the review and the send', () {
    testWidgets('the review lists what suppliers will read, and Edit goes back to that section', (tester) async {
      await open(tester);
      await fillEnquiry(tester);
      await send(tester);
      expect(find.text('Review your enquiry'), findsOneWidget);
      expect(
        find.descendant(of: key('review-describe-Title'), matching: find.text('IT & ITES — Security Services')),
        findsOneWidget,
      );
      expect(find.descendant(of: key('review-location-Locations'), matching: find.text('Pune')), findsOneWidget);
      expect(find.text('Bharat Facilities · Bharat Buyer · +919879879898'), findsOneWidget);
      expect(find.text('Every supplier that matches'), findsOneWidget);
      expect(repo.created, isEmpty, reason: 'nothing is sent before the review is confirmed');
      await tester.tap(key('review-edit-service'));
      await settle(tester, 12);
      expect(find.text('Review your enquiry'), findsNothing);
      expect(key('category-field'), findsOneWidget);
      await tester.tap(key('send'));
      await settle(tester, 12);
      await tester.tap(key('review-keep'));
      await settle(tester, 12);
      expect(repo.created, isEmpty);
    });

    testWidgets('confirming sends the enquiry as the API takes it, and says how many suppliers it reached', (
      tester,
    ) async {
      await open(tester);
      await fillEnquiry(tester);
      await type(tester, 'budget', '6,50,000');
      await send(tester);
      await tester.tap(key('review-confirm'));
      await settle(tester, 12);
      final body = repo.created.single;
      expect(body['kind'], 'ENQUIRY');
      expect(body['status'], 'PUBLISHED');
      expect(body['visibility'], 'PUBLIC');
      expect(body['title'], 'IT & ITES — Security Services');
      expect(body['description'], startsWith('Round-the-clock'));
      expect(body['facilityType'], 'IT & ITES');
      expect(body['category'], 'SECURITY');
      expect(body['budget'], 650000);
      expect(body['contactName'], 'Bharat Buyer');
      expect(body['contactEmail'], 'buyer@icr.dev');
      expect(body['contactPhone'], '+919879879898');
      expect(body['companyName'], 'Bharat Facilities');
      // Each place as picked, and the older fields worked out from it.
      expect(body['serviceLocations'], [
        {'label': 'Pune', 'city': 'Pune', 'state': 'Maharashtra', 'country': 'India', 'countryCode': 'IN'},
      ]);
      expect(body['locations'], ['Pune']);
      expect(body['state'], 'Maharashtra');
      expect(body['country'], 'India');
      expect(find.text('Enquiry posted'), findsOneWidget);
      expect(find.text('Shared with 6 matched suppliers.'), findsOneWidget);
      expect(posted.single.kind, RfqKind.enquiry);
    });

    testWidgets('places in two countries send no single country or state', (tester) async {
      final d = RequirementDraft()
        ..places = [
          const RfqPlace(label: 'Pune', city: 'Pune', state: 'Maharashtra', country: 'India'),
          const RfqPlace(label: 'Dubai, United Arab Emirates', city: 'Dubai', country: 'United Arab Emirates'),
        ];
      expect(d.derivedCountry, '');
      expect(d.derivedState, '', reason: "Pune's state is not Dubai's");
      expect(d.cleanLocations, ['Pune', 'Dubai']);
      // A place typed by hand names neither, so neither is claimed for the others.
      d.places = [
        const RfqPlace(label: 'Pune', city: 'Pune', state: 'Maharashtra', country: 'India'),
        RfqPlace.typed('Khopoli'),
      ];
      expect(d.derivedState, '');
      expect(d.derivedCountry, '');
      d.places = [
        const RfqPlace(label: 'Pune', city: 'Pune', state: 'Maharashtra', country: 'India'),
        const RfqPlace(label: 'Mumbai', city: 'Mumbai', state: 'Maharashtra', country: 'India'),
      ];
      expect(d.derivedState, 'Maharashtra');
      expect(d.derivedCountry, 'India');
      d.places = [
        const RfqPlace(label: 'Pune', city: 'Pune', state: 'Maharashtra', country: 'India'),
        const RfqPlace(label: 'Dubai, United Arab Emirates', city: 'Dubai', country: 'United Arab Emirates'),
      ];
      final body = d.toUpdate(effectiveTitle: 't');
      expect(body.containsKey('country'), isFalse);
      expect(body.containsKey('state'), isFalse);
    });

    testWidgets('a refusal shows the API\'s own sentence, keeps everything typed, and the next send goes through', (
      tester,
    ) async {
      await open(tester);
      await fillEnquiry(tester);
      repo.refuseNextWrite = 'The deadline for responses has already passed.';
      await send(tester);
      await tester.tap(key('review-confirm'));
      await settle(tester, 12);
      expect(find.text('The deadline for responses has already passed.'), findsWidgets);
      expect(find.text('Review your enquiry'), findsOneWidget, reason: 'the review stays open so it can be sent again');
      expect(find.text('Enquiry posted'), findsNothing);
      await tester.tap(key('review-keep'));
      await settle(tester, 12);
      expect(tester.widget<TextField>(key('text')).controller!.text, startsWith('Round-the-clock'));
      expect(find.text('Pune'), findsWidgets);
      expect(
        find.text('The deadline for responses has already passed.'),
        findsOneWidget,
        reason: 'and the page says it too',
      );
      await send(tester);
      await tester.tap(key('review-confirm'));
      await settle(tester, 12);
      expect(find.text('Enquiry posted'), findsOneWidget);
      expect(repo.created, hasLength(1), reason: "the refused attempt never reached the API's create");
    });

    testWidgets('an account with no company is told so before the form, with the way to one', (tester) async {
      repo.poster = const Poster(
        id: 'bharat',
        name: 'Bharat Buyer',
        email: 'buyer@icr.dev',
        role: 'BUYER',
        phone: '+919879879898',
      );
      var created = 0;
      await open(tester, onCreateCompany: () => created++);
      expect(find.text('Requirements are posted for a company'), findsOneWidget);
      expect(find.text('Send enquiry'), findsNothing);
      expect(key('text'), findsNothing);
      await tester.tap(find.text('Create a company'));
      expect(created, 1);
      expect(links.opened, isEmpty, reason: 'the lead\'s screen opens, not the website');
    });

    testWidgets('with no callback wired, the way to a company opens the website page', (tester) async {
      repo.poster = const Poster(id: 'bharat', name: 'Bharat Buyer', email: 'buyer@icr.dev', role: 'BUYER');
      await open(tester);
      await tester.tap(find.text('Create a company'));
      await settle(tester);
      expect(links.opened.single.path, '/account/companies/new');
    });

    testWidgets('a failed load says so and Try again reads it again', (tester) async {
      repo.failReads = true;
      repo.failMe = true;
      await open(tester);
      expect(find.text("Couldn't open the form"), findsOneWidget);
      repo.failMe = false;
      repo.failReads = false;
      await tester.tap(find.text('Try again'));
      await settle(tester, 10);
      expect(find.text('Send enquiry'), findsOneWidget);
    });
  });

  group('drafts', () {
    testWidgets('Save draft sends it as a draft, held only to the fields\' own limits', (tester) async {
      await open(tester);
      await type(tester, 'title', 'Residential Communities: Home Security');
      await tapKey(tester, 'save-draft');
      expect(repo.created.single['status'], 'DRAFT');
      expect(find.text('Draft saved'), findsOneWidget);
      expect(find.textContaining('Only your team can see it'), findsOneWidget);
    });

    testWidgets('a draft still refuses what the API refuses at any status', (tester) async {
      await open(tester);
      await type(tester, 'budget', 'nonsense');
      await tapKey(tester, 'save-draft');
      expect(repo.created, isEmpty);
      expect(find.text('Enter an amount in rupees, like 50,00,000'), findsWidgets);
    });

    testWidgets('an invite-only enquiry goes out at once, never as a draft', (tester) async {
      final c = PostRfqController(repository: repo);
      await c.start();
      c.update((d) {
        d
          ..facilityType = 'IT & ITES'
          ..places = [RfqPlace.typed('Pune')]
          ..category = 'SECURITY'
          ..text = 'A private enquiry to two suppliers about guarding.'
          ..audience = Audience.invited
          ..invited = [DemoRfqRepository.blueDot];
      });
      expect(await c.submit(publish: false), isTrue);
      expect(repo.created.single['status'], 'PUBLISHED');
    });
  });

  group('edit and copy', () {
    testWidgets('editing a draft starts from it and Publish saves, then publishes', (tester) async {
      await open(tester, editId: DemoRfqRepository.homeId);
      expect(find.text('Edit requirement'), findsOneWidget);
      expect(find.text('Requirement of'), findsOneWidget);
      expect(tester.widget<TextField>(key('text')).controller!.text, startsWith('Alarm systems'));
      expect(find.text('Residential Communities'), findsWidgets);
      expect(find.text('Pune'), findsWidgets);
      expect(key('kind-enquiry'), findsOneWidget);
      expect(find.text('Publish'), findsOneWidget);
      expect(find.text('Save draft'), findsOneWidget);
      await type(tester, 'budget', '9,00,000');
      await tester.tap(key('send'));
      await settle(tester, 12);
      final (id, patch) = repo.patched.single;
      expect(id, DemoRfqRepository.homeId);
      expect(patch['budget'], 900000);
      expect(patch.containsKey('attachments'), isFalse, reason: 'the files are left alone unless they were changed');
      expect(patch.containsKey('items'), isFalse);
      expect(repo.calls, contains('act'));
      expect(find.text('Changes saved'), findsOneWidget);
      expect(posted.single.status, RfqStatus.published);
    });

    testWidgets('editing a live requirement offers Save changes only, and cannot change its kind', (tester) async {
      await open(tester, editId: DemoRfqRepository.securityId);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Save draft'), findsNothing);
      await tester.tap(key('kind-rfq'));
      await settle(tester);
      expect(find.text('Scope of services'), findsNothing, reason: 'a requirement keeps its kind');
      await type(tester, 'budget', '13,00,000');
      await tester.tap(key('send'));
      await settle(tester, 12);
      expect(repo.patched.single.$2['budget'], 1300000);
      expect(repo.calls, isNot(contains('act')));
    });

    testWidgets('a changed file list is sent whole, an unchanged one is not sent', (tester) async {
      await open(tester, editId: DemoRfqRepository.securityId);
      expect(key('file-row-0'), findsOneWidget);
      expect(tester.widget<TextField>(key('file-title-0')).controller!.text, 'Floor plan — HQ');
      await type(tester, 'file-title-0', 'Floor plan, HQ');
      await tester.tap(key('send'));
      await settle(tester, 12);
      final files = repo.patched.single.$2['attachments'] as List;
      expect(files.single['title'], 'Floor plan, HQ');
      expect(files.single['url'], '/uploads/demo-floor-plan.pdf');
    });

    testWidgets('"Post a similar requirement" starts from the old one with its dates and files left out', (
      tester,
    ) async {
      await open(tester, copyFrom: DemoRfqRepository.ifmId);
      expect(find.text('Post RFQ'), findsOneWidget);
      expect(find.text('Scope of services'), findsOneWidget);
      expect(tester.widget<TextField>(key('text')).controller!.text, startsWith('Integrated facility management'));
      expect(find.text('Pick a date'), findsNWidgets(2), reason: 'dates are picked anew');
      expect(
        find.text('Hide supplier criteria'),
        findsOneWidget,
        reason: "a copy's criteria are shown, so they are not sent unseen",
      );
      expect(tester.widget<TextField>(key('min-years')).controller!.text, '5');
      expect(find.text('Create RFQ'), findsOneWidget);
      expect(
        tester.widget<TextField>(key('title')).controller!.text,
        isEmpty,
        reason: 'a copy gets a title of its own',
      );
    });
  });

  group('leaving', () {
    testWidgets('a form with something typed asks first, and Keep editing stays', (tester) async {
      await open(tester);
      await type(tester, 'text', 'Round-the-clock guarding for the campus.');
      await tester.tap(find.bySemanticsLabel('Back'));
      await settle(tester, 10);
      expect(find.text('Leave without saving?'), findsOneWidget);
      await tester.tap(find.text('Keep editing').last);
      await settle(tester, 10);
      expect(find.byType(PostRfqScreen), findsOneWidget);
    });

    testWidgets('Leave goes back with no result, and an untouched form goes back at once', (tester) async {
      PostResult? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<PostResult>(
                    MaterialPageRoute(
                      builder: (_) => PostRfqScreen(repository: repo, links: links),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester, 14);
      await tester.tap(find.bySemanticsLabel('Back'));
      await settle(tester, 14);
      expect(find.byType(PostRfqScreen), findsNothing, reason: 'nothing typed, nothing to lose');
      expect(result, isNull);
    });
  });

  group('after a post', () {
    Future<void> postEnquiry(WidgetTester tester) async {
      await open(tester);
      await fillEnquiry(tester);
      await send(tester);
      await tester.tap(key('review-confirm'));
      await settle(tester, 12);
    }

    testWidgets('"View requirement" opens it, in place of the composer', (tester) async {
      await postEnquiry(tester);
      await tester.tap(key('posted-view'));
      await settle(tester, 14);
      expect(find.byType(RfqDetailScreen), findsOneWidget);
      expect(find.byType(PostRfqScreen), findsNothing);
    });

    testWidgets('"Post another" is a blank form for the same kind', (tester) async {
      await postEnquiry(tester);
      await tester.tap(key('posted-another'));
      await settle(tester, 10);
      expect(find.text('Send enquiry'), findsOneWidget);
      expect(tester.widget<TextField>(key('text')).controller!.text, isEmpty);
      expect(tester.widget<TextField>(key('contact-name')).controller!.text, 'Bharat Buyer');
      expect(key('place-chip-Pune'), findsNothing);
    });

    testWidgets('an RFQ names its pre-qualification deadline in what follows', (tester) async {
      await open(tester, kind: RfqKind.rfq);
      await fillEnquiry(tester);
      await tapKey(tester, 'prequal-date');
      await tester.tap(find.text('28'));
      await tester.tap(find.text('OK'));
      await settle(tester, 10);
      await tapKey(tester, 'due-date');
      await tester.tap(find.text('31'));
      await tester.tap(find.text('OK'));
      await settle(tester, 10);
      await send(tester);
      await tester.tap(key('review-confirm'));
      await settle(tester, 12);
      expect(find.text('RFQ created'), findsOneWidget);
      expect(find.text('Suppliers send pre-qualification responses until 28 Oct 2026.'), findsOneWidget);
    });
  });

  test('the rules: a facility type retired from the list is still accepted on an older requirement', () {
    expect(facilityTypes, isNot(contains('Corporate Offices')));
    final d = RequirementDraft()..facilityType = 'Corporate Offices';
    expect(d.facilityTypeAccepted, isTrue);
    d.facilityType = 'Spaceport';
    expect(d.problems(goingLive: false, askCompany: false, effectiveTitle: 't')['facilityType'], isNotNull);
  });
}

/// Answers the category list only when the test lets it, so the form can be left while it is still loading.
class _SlowCategories extends DemoRfqRepository {
  final gate = Completer<void>();

  @override
  Future<List<CategoryNode>> categories() async {
    await gate.future;
    return super.categories();
  }
}

class _SlowUpload extends DemoRfqRepository {
  @override
  Future<RfqFile> uploadFile(PickedRfqFile file, {required String purpose}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return super.uploadFile(file, purpose: purpose);
  }
}
