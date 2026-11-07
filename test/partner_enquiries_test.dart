import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/partner_enquiries/enquiries_repository.dart';
import 'package:icr_mobile/features/partner_enquiries/enquiries_screen.dart';
import 'package:icr_mobile/features/partner_enquiries/enquiry_models.dart';

import 'helpers/fonts.dart';

/// The partner institute's Enquiries (the website's `/admin/learning/enquiries`), native since 7 Nov 2026: the
/// owner's tap on "New enquiry about CSF from Bindhya S" was told "staff tools" instead of showing the enquiry.
void main() {
  setUpAll(loadAppFonts);

  late DemoEnquiriesRepository repo;

  Future<void> pump(WidgetTester tester, {DemoEnquiriesRepository? repository, String? focusId}) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = repository ?? DemoEnquiriesRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: PartnerEnquiriesScreen(onBack: () {}, repository: repo, focusId: focusId),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("lists every enquiry as the website's row: who, the kind and course, the contact, when, the message", (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Enquiries'), findsOneWidget);
    expect(find.text('Bindhya S'), findsOneWidget);
    expect(find.text('Individual'), findsWidgets);
    expect(find.text('CSF'), findsOneWidget);
    expect(find.text('bindhya@example.com'), findsOneWidget);
    expect(find.text('Is the next CSF batch on weekends? I work full time.'), findsOneWidget);
    expect(find.text('Priya Nair'), findsOneWidget);
    expect(find.text('Acme Workplace Services · ~40 people'), findsOneWidget);
    expect(find.text('Corporate training'), findsOneWidget);
    expect(find.text('Called 5 Nov; sending the corporate brochure.'), findsOneWidget, reason: 'the note, as saved');
    expect(find.byType(Card), findsNothing, reason: 'rows the whole width, hairlines between');
  });

  testWidgets("past the plan's number the contact is masked, with the website's reason", (tester) async {
    await pump(
      tester,
      repository: DemoEnquiriesRepository(
        reveal: const EnquiryReveal(monthly: 2, receivedThisMonth: 3, revealedThisMonth: 2),
      ),
    );
    expect(find.byKey(const ValueKey('masked-lead-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('masked-lead-1')), findsNothing);
    expect(
      find.text(
        '2 of 3 enquiries this month came with contact details — your plan includes 2 a month. The rest are here, '
        'with the details masked.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the status moves through the sheet and is sent; the note saves when the field is left', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('status-lead-1')));
    await tester.pumpAndSettle();
    expect(find.text('Status'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('status-option-CONTACTED')));
    await tester.pumpAndSettle();
    expect(repo.sent, [
      {'id': 'lead-1', 'status': 'CONTACTED'},
    ]);
    expect(
      find.descendant(of: find.byKey(const ValueKey('status-lead-1')), matching: find.text('Contacted')),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const ValueKey('note-lead-1')), 'Will call tomorrow');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repo.sent.last, {'id': 'lead-1', 'note': 'Will call tomorrow'});
    expect(find.text('Note saved.'), findsOneWidget);
  });

  testWidgets('the filter chips ask the API for one status; none of that status says so', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('filter-CONVERTED')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('enquiries-empty')), findsOneWidget);
    expect(find.text('No enquiries with that status.'), findsOneWidget);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Bindhya S'), findsOneWidget);
  });

  testWidgets('a notification opens the list on its enquiry, tinted', (tester) async {
    await pump(tester, focusId: 'lead-2');
    final row = tester.widget<Container>(
      find.ancestor(of: find.text('Priya Nair'), matching: find.byType(Container)).first,
    );
    expect(row.color, isNotNull, reason: 'the row the notification named is tinted');
    final other = tester.widget<Container>(
      find.ancestor(of: find.text('Bindhya S'), matching: find.byType(Container)).first,
    );
    expect(other.color, isNull);
  });

  testWidgets('a list that cannot be read says so and can be tried again', (tester) async {
    await pump(tester, repository: DemoEnquiriesRepository(failList: true));
    expect(find.byKey(const ValueKey('enquiries-error')), findsOneWidget);
    expect(find.text('Could not load enquiries.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('nothing yet says where the form is', (tester) async {
    await pump(tester, repository: DemoEnquiriesRepository(rows: []));
    expect(
      find.text('No enquiries yet. The form is on every course page of yours and on your institute page.'),
      findsOneWidget,
    );
  });
}
