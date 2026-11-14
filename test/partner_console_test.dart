import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/account/widgets/account_kit.dart' show AccountButton, EditSheet;
import 'package:icr_mobile/features/partner_console/batches_screen.dart';
import 'package:icr_mobile/features/partner_console/courses_screen.dart';
import 'package:icr_mobile/features/partner_console/enrolments_screen.dart';
import 'package:icr_mobile/features/partner_console/partner_console_kit.dart';
import 'package:icr_mobile/features/partner_console/partner_console_models.dart';
import 'package:icr_mobile/features/partner_console/partner_console_repository.dart';
import 'package:icr_mobile/features/partner_console/partner_console_rules.dart';

import 'helpers/fonts.dart';

/// The pickers, answering from a list instead of the phone's dialogs.
class FakePickers extends ConsolePickers {
  FakePickers({this.days = const [], this.times = const []});

  final List<DateTime> days;
  final List<TimeOfDay> times;
  int _day = 0;
  int _time = 0;

  @override
  Future<DateTime?> pickDay(
    BuildContext context, {
    required DateTime initial,
    required DateTime first,
    required DateTime last,
    String? help,
  }) async => _day < days.length ? days[_day++] : null;

  @override
  Future<TimeOfDay?> pickTime(BuildContext context, {required TimeOfDay initial, String? help}) async =>
      _time < times.length ? times[_time++] : null;

  @override
  Future<UploadFile?> pickImage() async => UploadFile(name: 'cover.png', bytes: Uint8List(16), mimeType: 'image/png');

  @override
  Future<UploadFile?> pickPdf() async =>
      UploadFile(name: 'brochure.pdf', bytes: Uint8List(16), mimeType: 'application/pdf');
}

/// The partner institute's Learning console — Manage Courses, Manage Batches and Enrolment — as the website's
/// `/admin/learning/courses`, `/batches` and `/enrolments` draw them for a partner.
void main() {
  setUpAll(loadAppFonts);

  /// 12 Nov 2026, 06:00 UTC — the day the samples were written for.
  DateTime now() => DateTime.utc(2026, 11, 12, 6);

  const trainer = PartnerConsoleViewer(role: 'PROFESSIONAL', learningRoles: ['TRAINER'], companyId: 'co-1');
  const stranger = PartnerConsoleViewer(role: 'PROFESSIONAL');

  late DemoPartnerConsoleRepository repo;

  void usePhone(WidgetTester tester, {double height = 2400}) {
    tester.view.physicalSize = Size(390, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: screen));
    await tester.pumpAndSettle();
  }

  Future<void> pumpCourses(
    WidgetTester tester, {
    DemoPartnerConsoleRepository? repository,
    PartnerConsoleViewer? viewer,
    ConsolePickers? pickers,
  }) async {
    usePhone(tester);
    repo = repository ?? DemoPartnerConsoleRepository();
    await pump(
      tester,
      ManageCoursesScreen(onBack: () {}, repository: repo, viewer: viewer, pickers: pickers ?? FakePickers(), now: now),
    );
  }

  Future<void> pumpBatches(
    WidgetTester tester, {
    DemoPartnerConsoleRepository? repository,
    PartnerConsoleViewer? viewer,
    ConsolePickers? pickers,
    String? courseId,
  }) async {
    usePhone(tester);
    repo = repository ?? DemoPartnerConsoleRepository();
    await pump(
      tester,
      ManageBatchesScreen(
        onBack: () {},
        courseId: courseId,
        repository: repo,
        viewer: viewer,
        pickers: pickers ?? FakePickers(),
        now: now,
      ),
    );
  }

  Future<void> pumpEnrolments(
    WidgetTester tester, {
    DemoPartnerConsoleRepository? repository,
    PartnerConsoleViewer? viewer,
    String? courseId,
  }) async {
    usePhone(tester);
    repo = repository ?? DemoPartnerConsoleRepository();
    await pump(tester, EnrolmentsScreen(onBack: () {}, repository: repo, viewer: viewer, courseId: courseId));
  }

  /// Taps a widget after bringing it into view (the sheets scroll).
  Future<void> tapKey(WidgetTester tester, Key key) async {
    final target = find.byKey(key);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// Opens a select field (its inner tap target) and picks a row of the list by its words.
  Future<void> pickFrom(WidgetTester tester, Key fieldKey, String label) async {
    final field = find.descendant(of: find.byKey(fieldKey), matching: find.byType(InkWell));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, Key key, String text) async {
    final target = find.byKey(key);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.enterText(target, text);
    await tester.pumpAndSettle();
  }

  /// A text field holding [text] (a field's hint is built too, hidden, so `find.text` would see it twice).
  Finder fieldWithText(String text) => find.byWidgetPredicate((w) => w is EditableText && w.controller.text == text);

  String chipText(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.descendant(of: find.byKey(key), matching: find.byType(Text))).data!;

  group('Manage Courses', () {
    testWidgets(
      "lists the institute's courses as the website's rows: code, name, status, format, duration, next batch, "
      'batches and CPD, with the unpublished note',
      (tester) async {
        await pumpCourses(tester);
        expect(find.text('Manage Courses'), findsOneWidget);
        expect(find.text('2 courses · 3 batches'), findsOneWidget);
        expect(find.text('FMF'), findsOneWidget);
        expect(find.text('Facility Management Fundamentals'), findsOneWidget);
        expect(find.text('EAW'), findsOneWidget);
        expect(chipText(tester, const ValueKey('status-course-1')), 'Live');
        expect(chipText(tester, const ValueKey('status-course-2')), 'Draft');
        expect(
          find.text('Virtual live training · 8 weeks · 48 hours · Next batch 6 Mar 2027 · 2 batches · 12 CPD'),
          findsOneWidget,
        );
        expect(find.textContaining('1 course is not published.'), findsOneWidget);
        // The live course offers Unpublish; the draft with a scheduled batch offers Publish.
        expect(find.byKey(const ValueKey('unpublish-course-1')), findsOneWidget);
        expect(find.byKey(const ValueKey('publish-course-2')), findsOneWidget);
        expect(find.byType(Card), findsNothing, reason: 'rows the whole width, hairlines between');
      },
    );

    testWidgets("a course is created with the website's fields and saved as a draft, which needs a batch to publish", (
      tester,
    ) async {
      await pumpCourses(tester);
      await tapKey(tester, const ValueKey('courses-new'));
      expect(find.descendant(of: find.byType(EditSheet), matching: find.text('New Course')), findsOneWidget);
      expect(find.text('Saved as a draft. Add a batch from the list, then publish it.'), findsOneWidget);
      // Save waits for a name and a category, as the website's button does.
      expect(tester.widget<AccountButton>(find.byKey(const Key('sheet.save'))).onPressed, isNull);

      await type(tester, const Key('course.title'), 'Fire Safety Essentials');
      await type(tester, const Key('course.summary'), 'A day on alarms, drills and evacuation for building teams.');
      await pickFrom(tester, const Key('course.category'), 'Sustainability');
      await pickFrom(tester, const Key('course.subcategory'), 'Energy Management');
      await type(tester, const Key('course.overview'), 'What the day covers and why it matters.');
      await tapKey(tester, const ValueKey('list-Key Takeaways-add'));
      await type(tester, const ValueKey('list-Key Takeaways-0'), 'Run a fire drill');
      await tapKey(tester, const ValueKey('list-Who Should Attend-add'));
      await type(tester, const ValueKey('list-Who Should Attend-0'), 'Facility teams');
      await pickFrom(tester, const Key('course.access'), 'Paid');
      await tapKey(tester, const Key('sheet.save'));

      final body = repo.sent.single;
      expect(body['action'], 'createCourse');
      expect(body, containsPair('kind', 'DEVELOPMENT'));
      expect(body, containsPair('status', 'DRAFT'));
      expect(body, containsPair('title', 'Fire Safety Essentials'));
      expect(body, containsPair('summary', 'A day on alarms, drills and evacuation for building teams.'));
      expect(body, containsPair('category', 'SUSTAINABILITY'));
      expect(body, containsPair('subcategory', 'ENERGY_MANAGEMENT'));
      expect(body, containsPair('description', 'What the day covers and why it matters.'));
      expect(body, containsPair('learningOutcomes', ['Run a fire drill']));
      expect(body, containsPair('audience', ['Facility teams']));
      expect(body, containsPair('access', 'PAID'));
      expect(body, containsPair('level', 'FOUNDATION'));

      // Back on the list: a draft with no batch yet, which says what is missing.
      expect(find.text('Fire Safety Essentials'), findsOneWidget);
      expect(find.text('3 courses · 3 batches'), findsOneWidget);
      expect(find.byKey(const ValueKey('needs-batch-course-new-1')), findsOneWidget);
      expect(find.text('Add a batch to publish'), findsOneWidget);
    });

    testWidgets(
      "under ICR's course review a draft with a batch is submitted, then reads With ICR for review and offers "
      'Withdraw',
      (tester) async {
        await pumpCourses(
          tester,
          repository: DemoPartnerConsoleRepository(
            context: const ConsoleContext(
              isPartner: true,
              providerId: 'inst-1',
              partnerStatus: 'ACTIVE',
              capabilities: ['COURSE_LISTING', 'BATCHES', 'ENROLMENT'],
              courseReviewRequired: true,
            ),
          ),
        );
        expect(find.byKey(const ValueKey('publish-course-2')), findsNothing);
        await tapKey(tester, const ValueKey('submit-course-2'));
        expect(repo.sent, [
          {'action': 'submitCourse', 'id': 'course-2'},
        ]);
        expect(chipText(tester, const ValueKey('status-course-2')), 'With ICR for review');
        expect(find.byKey(const ValueKey('withdraw-course-2')), findsOneWidget);
      },
    );

    testWidgets("without ICR's review the row's Publish puts a course live, and Edit reopens its fields", (
      tester,
    ) async {
      await pumpCourses(tester);
      await tapKey(tester, const ValueKey('publish-course-2'));
      expect(repo.sent.last, {'action': 'updateCourse', 'id': 'course-2', 'status': 'PUBLISHED'});
      expect(chipText(tester, const ValueKey('status-course-2')), 'Live');

      await tapKey(tester, const ValueKey('edit-course-1'));
      expect(find.descendant(of: find.byType(EditSheet), matching: find.text('Edit Course')), findsOneWidget);
      expect(find.text('Facility Management Fundamentals'), findsWidgets);
      expect(fieldWithText('Apply FM best practices across operations and maintenance'), findsOneWidget);
      expect(fieldWithText('Read a maintenance contract and know what it promises'), findsOneWidget);
      expect(find.text('Housekeeping'), findsOneWidget, reason: 'the sub-category reads by its name');
    });

    testWidgets("a Trainer's roles see the courses but none of the buttons", (tester) async {
      await pumpCourses(tester, viewer: trainer);
      expect(find.text('FMF'), findsOneWidget);
      expect(find.byKey(const ValueKey('courses-new')), findsNothing);
      expect(find.byKey(const ValueKey('edit-course-1')), findsNothing);
      expect(find.byKey(const ValueKey('publish-course-2')), findsNothing);
    });

    testWidgets('a list that cannot be read says so and can be tried again', (tester) async {
      await pumpCourses(tester, repository: DemoPartnerConsoleRepository(failList: true));
      expect(find.byKey(const ValueKey('courses-error')), findsOneWidget);
      expect(find.text('Could not load courses.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });
  });

  group('Manage Batches', () {
    testWidgets('lists every run soonest first with the status its dates give today; the course filter narrows it', (
      tester,
    ) async {
      await pumpBatches(tester);
      expect(find.text('Manage Batches'), findsOneWidget);
      expect(find.text('3 batches'), findsOneWidget);
      expect(find.text('FMF-202610'), findsOneWidget, reason: 'a batch with no name reads by its code');
      expect(find.text('January 2027'), findsOneWidget);
      expect(find.text('March 2027 — weekend'), findsOneWidget);
      expect(find.text('FMF · Starts 6 Mar 2027 · 9/25 seats'), findsOneWidget);
      expect(chipText(tester, const ValueKey('batch-status-batch-2')), 'Completed');
      expect(chipText(tester, const ValueKey('batch-status-batch-3')), 'Scheduled', reason: 'enrolment closed');
      expect(chipText(tester, const ValueKey('batch-status-batch-1')), 'Open for enrolment');
      final order = [
        tester.getTopLeft(find.byKey(const ValueKey('batch-batch-2'))).dy,
        tester.getTopLeft(find.byKey(const ValueKey('batch-batch-3'))).dy,
        tester.getTopLeft(find.byKey(const ValueKey('batch-batch-1'))).dy,
      ];
      expect(order, orderedEquals([...order]..sort()), reason: 'soonest first');

      await pickFrom(tester, const ValueKey('batches-course-filter'), 'EAW — Energy Audit Workshop');
      expect(find.text('1 batch'), findsOneWidget);
      expect(find.text('January 2027'), findsOneWidget);
      expect(find.text('March 2027 — weekend'), findsNothing);
    });

    testWidgets("a batch is created for a course with the website's fields; the required ones are named first", (
      tester,
    ) async {
      await pumpBatches(
        tester,
        courseId: 'course-2',
        pickers: FakePickers(
          days: [DateTime(2027, 5, 3), DateTime(2027, 5, 28)],
          times: const [TimeOfDay(hour: 10, minute: 0), TimeOfDay(hour: 13, minute: 0)],
        ),
      );
      await tapKey(tester, const ValueKey('batches-new'));
      expect(find.text('Energy Audit Workshop'), findsOneWidget, reason: 'the sheet is titled with the course');
      expect(find.text('This course is free. Set its Access to Paid to price its batches.'), findsOneWidget);

      await tapKey(tester, const Key('sheet.save'));
      expect(
        find.text('Fill in the required fields: Batch Starts, Batch Ends, Class Starts, Class Ends.'),
        findsOneWidget,
      );
      expect(repo.sent, isEmpty);

      await tapKey(tester, const Key('batch.startsAt'));
      expect(find.text('3 May 2027'), findsOneWidget);
      await tapKey(tester, const Key('batch.endsAt'));
      expect(find.text('28 May 2027'), findsOneWidget);
      // Every weekday starts ticked; the weekend comes off.
      await tapKey(tester, const ValueKey('batch.day.6'));
      await tapKey(tester, const ValueKey('batch.day.0'));
      await tapKey(tester, const Key('batch.classStart'));
      await tapKey(tester, const Key('batch.classEnd'));
      expect(find.text('10:00 AM'), findsOneWidget);
      expect(find.text('1:00 PM'), findsOneWidget);
      expect(find.text('Mon–Fri, 10:00–13:00 · 20 classes · 60 hours'), findsOneWidget);
      await type(tester, const Key('batch.size'), '30');
      await tapKey(tester, const Key('sheet.save'));

      final body = repo.sent.single;
      expect(body['action'], 'createBatch');
      expect(body['courseId'], 'course-2');
      expect(body, containsPair('startsAt', '2027-05-03T00:00:00.000Z'));
      expect(body, containsPair('endsAt', '2027-05-28T00:00:00.000Z'));
      expect(body, containsPair('mode', 'VIRTUAL'));
      expect(body, containsPair('classDays', [1, 2, 3, 4, 5]));
      expect(body, containsPair('classStartTime', '10:00'));
      expect(body, containsPair('classEndTime', '13:00'));
      expect(body, containsPair('timezone', 'Asia/Kolkata'));
      expect(body, containsPair('maxSeats', 30));
      expect(body, containsPair('trainerIds', <String>[]));
      expect(body, containsPair('enrolmentSpecialistId', null));
      expect(body, containsPair('waitlistEnabled', true));
      expect(body, containsPair('discountPercent', 0));
      expect(body, isNot(contains('status')), reason: 'the dates set it; nobody picks a status');

      expect(find.text('May 2027'), findsOneWidget, reason: 'named after its start month');
      expect(find.text('EAW · Starts 3 May 2027 · 0/30 seats'), findsOneWidget);
      expect(chipText(tester, const ValueKey('batch-status-batch-new-1')), 'Open for enrolment');
    });

    testWidgets("a row opens the batch in full with the website's facts; Edit opens the sheet on its price and offer", (
      tester,
    ) async {
      await pumpBatches(tester);
      await tapKey(tester, const ValueKey('batch-batch-1'));
      expect(find.byKey(const Key('batchView.title')), findsOneWidget);
      expect(find.text('FMF · Facility Management Fundamentals · FMF-202703'), findsOneWidget);
      expect(find.text('Sat & Sun, 10:00–13:00'), findsOneWidget);
      expect(find.text('9 of 25'), findsOneWidget);
      expect(find.text('₹18,000'), findsOneWidget);
      expect(find.text('10% off until 15 Feb 2027'), findsOneWidget);
      expect(find.text('Meera Iyer'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Arjun Shetty'), findsOneWidget);
      expect(find.text('Waiting for their answer'), findsOneWidget);
      expect(find.text('Kavya Rao'), findsOneWidget);
      expect(find.text('Second weekend run; the first filled in three weeks.'), findsOneWidget);

      await tapKey(tester, const Key('batchView.edit'));
      expect(find.text('Facility Management Fundamentals - FMF-202703'), findsOneWidget);
      expect(find.text('Cancel This Batch'), findsOneWidget);
      expect(find.byKey(const Key('batch.price')), findsOneWidget);
      expect(find.text('Learners pay ₹16,200 + GST instead of ₹18,000 (10% off, until 15 Feb 2027).'), findsOneWidget);
      expect(find.text('Meera Iyer, Arjun Shetty'), findsOneWidget, reason: 'the trainers field reads the picked');
    });

    testWidgets("a Trainer's roles see the batches but cannot add or edit one", (tester) async {
      await pumpBatches(tester, viewer: trainer);
      expect(find.text('3 batches'), findsOneWidget);
      expect(find.byKey(const ValueKey('batches-new')), findsNothing);
      await tapKey(tester, const ValueKey('batch-batch-1'));
      expect(find.byKey(const Key('batchView.edit')), findsNothing);
      expect(find.byKey(const Key('batchView.delete')), findsNothing);
    });
  });

  group('Enrolment', () {
    testWidgets("lists who enrolled as the website's rows; a decision is sent and the row follows", (tester) async {
      await pumpEnrolments(tester);
      expect(find.text('Enrolment'), findsOneWidget);
      expect(find.text('3 enrolments'), findsOneWidget);
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('FMF · Applied 8 Nov 2026'), findsOneWidget);
      expect(chipText(tester, const ValueKey('enrolment-status-enr-1')), 'Pending');
      expect(chipText(tester, const ValueKey('enrolment-status-enr-3')), 'Waitlisted');

      await tapKey(tester, const ValueKey('enrolment-enr-1'));
      expect(find.text('asha.rao@example.com'), findsOneWidget);
      expect(find.text('FMF · Facility Management Fundamentals'), findsOneWidget);
      expect(find.text('March 2027 — weekend'), findsOneWidget);
      expect(find.text('I manage two office floors in Pune and want the weekend batch.'), findsOneWidget);
      await tapKey(tester, const Key('enrolment.confirm'));
      expect(repo.sent, [
        {'action': 'setEnrolmentStatus', 'id': 'enr-1', 'status': 'CONFIRMED'},
      ]);
      expect(chipText(tester, const ValueKey('enrolment-status-enr-1')), 'Confirmed');

      await tapKey(tester, const ValueKey('filter-CANCELLED'));
      expect(find.text('No enrolments match these filters.'), findsOneWidget);
    });

    testWidgets("the API's refusal is shown above the list, as the website shows it, and the row keeps its status", (
      tester,
    ) async {
      const full = 'That batch is full. Increase the seat count before confirming more candidates.';
      await pumpEnrolments(tester, repository: DemoPartnerConsoleRepository(refuse: full));
      await tapKey(tester, const ValueKey('enrolment-enr-1'));
      await tapKey(tester, const Key('enrolment.confirm'));
      expect(find.byKey(const ValueKey('enrolments-inline-error')), findsOneWidget);
      expect(find.text(full), findsOneWidget);
      expect(chipText(tester, const ValueKey('enrolment-status-enr-1')), 'Pending');
    });

    testWidgets("a plan that leaves participant management out shows the plan's sentence", (tester) async {
      await pumpEnrolments(
        tester,
        repository: DemoPartnerConsoleRepository(lockEnrolments: 'Your plan does not include participant management.'),
      );
      expect(find.byKey(const ValueKey('enrolments-lock')), findsOneWidget);
      expect(find.text('Participant Management'), findsOneWidget);
      expect(
        find.text('Your plan does not include participant management. A larger Institution plan includes it.'),
        findsOneWidget,
      );
    });

    testWidgets("a Trainer's roles read the enrolments but take no decision", (tester) async {
      await pumpEnrolments(tester, viewer: trainer);
      await tapKey(tester, const ValueKey('enrolment-enr-1'));
      expect(find.byKey(const Key('enrolment.confirm')), findsNothing);
      expect(find.byKey(const Key('enrolment.cancel')), findsNothing);
    });

    testWidgets('opened from a course row it is narrowed to that course', (tester) async {
      await pumpEnrolments(tester, courseId: 'course-2');
      expect(find.text('EAW — Energy Audit Workshop'), findsOneWidget);
      expect(find.text('1 enrolment'), findsOneWidget);
      expect(find.text('Neha Kulkarni'), findsOneWidget);
      expect(find.text('Asha Rao'), findsNothing);
    });
  });

  testWidgets("a member who is not the institute's staff is told the console is the institute's", (tester) async {
    await pumpCourses(tester, viewer: stranger);
    expect(find.byKey(const Key('partner-console-notice')), findsOneWidget);
    expect(find.text(notPartnerTitle), findsOneWidget);
    expect(find.text('FMF'), findsNothing);

    await pumpBatches(tester, viewer: stranger);
    expect(find.byKey(const Key('partner-console-notice')), findsOneWidget);

    await pumpEnrolments(tester, viewer: stranger);
    expect(find.byKey(const Key('partner-console-notice')), findsOneWidget);
  });
}
