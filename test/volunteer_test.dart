import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/config.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/contact/contact_models.dart';
import 'package:icr_mobile/features/volunteer/api_volunteer_repository.dart';
import 'package:icr_mobile/features/volunteer/demo_volunteer_repository.dart';
import 'package:icr_mobile/features/volunteer/get_involved_screen.dart';
import 'package:icr_mobile/features/volunteer/volunteer_apply_screen.dart';
import 'package:icr_mobile/features/volunteer/volunteer_controller.dart';
import 'package:icr_mobile/features/volunteer/volunteer_data.dart';
import 'package:icr_mobile/features/volunteer/volunteer_models.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'helpers/community_fakes.dart';
import 'helpers/fonts.dart';

/// A phone 390 dp wide and [height] dp tall: tall enough that the list builds every role.
void _view(WidgetTester tester, {double height = 14000}) {
  tester.view.physicalSize = Size(780, height * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

class _Page {
  _Page(this.repo) : controller = VolunteerController(repo);

  final FakeVolunteer repo;
  final VolunteerController controller;
  int backs = 0;
  int bells = 0;
  int mentors = 0;
  int chapters = 0;
  final opened = <Uri>[];

  Future<void> open(BuildContext context, Uri uri) async => opened.add(uri);
}

Future<_Page> _pump(
  WidgetTester tester, {
  FakeVolunteer? repo,
  VolunteerIntent? intent,
  bool mentor = true,
  bool chapters = true,
  bool ownBell = false,
  double height = 14000,
}) async {
  _view(tester, height: height);
  final page = _Page(repo ?? FakeVolunteer());
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: ChangeNotifierProvider.value(
        value: page.controller,
        child: GetInvolvedScreen(
          onBack: () => page.backs++,
          onBell: ownBell ? () => page.bells++ : null,
          onBecomeMentor: mentor ? () => page.mentors++ : null,
          onOpenChapters: chapters ? () => page.chapters++ : null,
          intent: intent,
          opener: page.open,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return page;
}

Finder _field(String key) => find.byKey(Key(key));

void main() {
  setUpAll(loadAppFonts);

  group('the opportunities and the application text', () {
    test('there are the website’s twenty roles, each with its own key, duties, time and glyph', () {
      expect(volunteerRoles, hasLength(20));
      expect({for (final r in volunteerRoles) r.key}, hasLength(20));
      for (final r in volunteerRoles) {
        expect(r.title, isNotEmpty, reason: r.key);
        expect(r.description, isNotEmpty, reason: r.key);
        expect(r.responsibilities, hasLength(4), reason: r.key);
        expect(r.commitment, isNotEmpty, reason: r.key);
        expect(volunteerIcon(r.icon), isNot(LucideIcons.heartHandshake), reason: '${r.key} has a glyph of its own');
      }
      expect(volunteerRoles.first.title, 'Chapter Committee Member');
      expect(volunteerRoles.first.commitment, '4–6 hours per month');
      expect(volunteerBenefits, hasLength(7));
      expect(volunteerCreditCopy.map((c) => c.$1), ['Mentoring', 'Volunteering', 'Committee']);
    });

    test('a role matches a search by its title, its description or any duty', () {
      final mentor = volunteerRoles.firstWhere((r) => r.key == 'mentor');
      expect(mentor.matches(''), isTrue);
      expect(mentor.matches('  coach '), isTrue);
      expect(mentor.matches('mentee regularly'), isTrue);
      expect(mentor.matches('structured ICR mentoring'), isTrue);
      expect(mentor.matches('zebra'), isFalse);
    });

    test('the interest goes to the team as: the role, its time, the chapter, then the person’s own words', () {
      final role = volunteerRoles.first;
      const a = VolunteerApplication(
        name: 'N',
        email: 'n@x.com',
        message: '  I run a campus.  ',
        chapter: ' ICR Bengaluru Chapter ',
      );
      expect(
        VolunteerApplication(name: a.name, email: a.email, message: a.message, role: role, chapter: a.chapter).composed,
        'Volunteer application: Chapter Committee Member\n'
        'Commitment: 4–6 hours per month\n'
        'Chapter: ICR Bengaluru Chapter\n'
        '\n'
        'I run a campus.',
      );
      expect(a.composed, 'Volunteer interest (no particular role)\nChapter: ICR Bengaluru Chapter\n\nI run a campus.');
      expect(
        const VolunteerApplication(name: 'N', email: 'e', message: 'Hi').composed,
        'Volunteer interest (no particular role)\n\nHi',
      );
    });

    test('the message may use the API’s 4,000 characters less the lines above it', () {
      final role = volunteerRoles.first;
      final head = VolunteerApplication(name: '', email: '', message: '', role: role, chapter: 'X').composed.length;
      expect(VolunteerApplication.messageRoom(role: role, chapter: 'X'), ContactLimits.message - head);
      expect(
        VolunteerApplication.messageRoom(),
        greaterThan(VolunteerApplication.messageRoom(role: role, chapter: 'X')),
      );
    });

    test('hours read as the ledger does: whole hours bare, halves and quarters to the hundredth', () {
      expect(CpdSummary.hoursLabel(12), '12');
      expect(CpdSummary.hoursLabel(8.5), '8.5');
      expect(CpdSummary.hoursLabel(3.25), '3.25');
      expect(CpdSummary.sourceLabel('MANUAL'), 'Manually recorded');
      expect(CpdSummary.sourceLabel('NEW_SOURCE'), 'NEW_SOURCE');
    });

    test('a chapter’s page asks for a committee seat at that chapter', () {
      const i = VolunteerIntent.chapter('ICR Pune Chapter');
      expect(i.roleKey, 'chapter-committee-member');
      expect(i.chapterName, 'ICR Pune Chapter');
    });
  });

  group('the API mapping', () {
    TableApi api({bool signedIn = true}) => TableApi({
      'GET /mentorship/cpd/summary': (_) => signedIn
          ? {
              'totalHours': 12,
              'hoursThisYear': 8.5,
              'bySource': [
                {'source': 'COURSE', 'hours': 6.5},
                {'source': 'MENTORING', 'hours': 2},
              ],
              'recent': [
                {
                  'id': 'e1',
                  'hours': 3,
                  'source': 'COURSE',
                  'sourceRefId': 'x',
                  'description': 'Course · FM Essentials',
                  'awardedAt': '2026-08-20T09:00:00.000Z',
                },
                {
                  'id': 'e2',
                  'hours': 2.5,
                  'source': 'MANUAL',
                  'sourceRefId': null,
                  'description': null,
                  'awardedAt': '2026-07-01T09:00:00.000Z',
                },
              ],
            }
          : (401, '{"message":"Unauthorized"}'),
      'GET /mentorship/cpd/target': (_) => {
        'year': 2026,
        'targetHours': 15,
        'achievedHours': 8.5,
        'progress': 0.5666,
        'isDefault': false,
      },
      'GET /auth/me': (_) => signedIn
          ? {
              'id': 'u1',
              'firstName': 'Bharat',
              'lastName': 'Buyer',
              'email': 'buyer@icr.dev',
              'role': 'BUYER',
              'phone': '+919876543210',
            }
          : (401, '{"message":"Unauthorized"}'),
      'GET /chapters': (_) => {
        'data': [
          {'id': 'c2', 'name': 'ICR Mumbai Chapter', 'city': 'Mumbai'},
          {'id': 'c1', 'name': 'ICR Bengaluru Chapter', 'city': 'Bengaluru'},
        ],
        'meta': {'page': 1, 'limit': 100, 'total': 2, 'totalPages': 1, 'hasNext': false, 'hasPrev': false},
      },
      'POST /contact': (_) => {'id': 'lead1'},
      'GET /notifications/unread-count': (_) => {'unread': 4},
    });

    test('the ledger is the API’s: totals, sources, the latest entries and the year’s target', () async {
      final repo = ApiVolunteerRepository(api: api().client());
      final cpd = (await repo.cpd())!;
      expect(cpd.totalHours, 12);
      expect(cpd.hoursThisYear, 8.5);
      expect(cpd.bySource.map((s) => (s.source, s.hours)), [('COURSE', 6.5), ('MENTORING', 2.0)]);
      expect(cpd.recent.map((e) => e.id), ['e1', 'e2']);
      expect(cpd.recent.first.description, 'Course · FM Essentials');
      expect(cpd.recent.first.awardedAt, DateTime.utc(2026, 8, 20, 9));
      expect(cpd.recent.last.description, isNull);
      expect(cpd.year, 2026);
      expect(cpd.targetHours, 15);
      expect(cpd.progress, closeTo(0.5666, 0.0001));
      expect(cpd.targetIsDefault, isFalse);
    });

    test('signed out there is no ledger, and a target that will not read leaves the ledger standing', () async {
      expect(await ApiVolunteerRepository(api: api(signedIn: false).client()).cpd(), isNull);
      final table = api()..routes['GET /mentorship/cpd/target'] = (_) => (500, '{"message":"boom"}');
      final cpd = (await ApiVolunteerRepository(api: table.client()).cpd())!;
      expect(cpd.totalHours, 12);
      expect(cpd.targetHours, isNull);
      expect(cpd.progress, isNull);
      table.routes['GET /mentorship/cpd/summary'] = (_) => (500, '{"message":"The ledger is down."}');
      await expectLater(
        ApiVolunteerRepository(api: table.client()).cpd(),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', 'The ledger is down.')),
      );
    });

    test('the form starts from the signed-in person; signed out it starts empty', () async {
      final s = (await ApiVolunteerRepository(api: api().client()).sender())!;
      expect((s.name, s.email, s.phone), ('Bharat Buyer', 'buyer@icr.dev', '+919876543210'));
      expect(await ApiVolunteerRepository(api: api(signedIn: false).client()).sender(), isNull);
    });

    test('the chapters are every published one, by name', () async {
      final table = api();
      final list = await ApiVolunteerRepository(api: table.client()).chapters();
      expect(list.map((c) => c.name), ['ICR Bengaluru Chapter', 'ICR Mumbai Chapter']);
      expect(list.first.city, 'Bengaluru');
      expect(table.queryOf('GET /chapters')['limit'], 100);
    });

    test(
      'an application is the website’s contact form, topic VOLUNTEER, with the composed message and no honeypot',
      () async {
        final table = api();
        final repo = ApiVolunteerRepository(api: table.client());
        await repo.apply(
          VolunteerApplication(
            name: ' Bharat Buyer ',
            email: ' buyer@icr.dev ',
            phone: ' +919876543210 ',
            message: 'I can give a day a month.',
            role: volunteerRoles.firstWhere((r) => r.key == 'speaker'),
            chapter: 'ICR Mumbai Chapter',
          ),
        );
        final body = table.lastOf('POST /contact').data as Map;
        expect(body, {
          'name': 'Bharat Buyer',
          'email': 'buyer@icr.dev',
          'phone': '+919876543210',
          'topic': 'VOLUNTEER',
          'message':
              'Volunteer application: Speaker or Panelist\nCommitment: Per event — 3–5 hours including preparation\nChapter: ICR Mumbai Chapter\n\nI can give a day a month.',
        });
        expect(body.containsKey('website'), isFalse);
        await repo.apply(const VolunteerApplication(name: 'N', email: 'n@x.com', message: 'Hi'));
        expect((table.lastOf('POST /contact').data as Map).containsKey('phone'), isFalse);
      },
    );

    test(
      'a refusal is the API’s own words, a list of them joined; the throttle is worded as the app words it',
      () async {
        final table = api();
        table.routes['POST /contact'] = (_) =>
            (400, '{"message":["email must be an email","message should not be empty"]}');
        final repo = ApiVolunteerRepository(api: table.client());
        const a = VolunteerApplication(name: 'N', email: 'n@x.com', message: 'Hi');
        await expectLater(
          repo.apply(a),
          throwsA(
            isA<ApiError>().having((e) => e.message, 'message', 'email must be an email\nmessage should not be empty'),
          ),
        );
        table.routes['POST /contact'] = (_) => (429, '{"message":"ThrottlerException: Too Many Requests"}');
        await expectLater(
          repo.apply(a),
          throwsA(
            isA<ApiError>()
                .having((e) => e.statusCode, 'status', 429)
                .having((e) => e.message, 'message', contains('Too many requests')),
          ),
        );
      },
    );

    test('the bell is the unread count, and 0 signed out', () async {
      expect(await ApiVolunteerRepository(api: api().client()).unreadNotifications(), 4);
      final table = api()..routes['GET /notifications/unread-count'] = (_) => (401, '{"message":"Unauthorized"}');
      expect(await ApiVolunteerRepository(api: table.client()).unreadNotifications(), 0);
    });
  });

  group('the controllers', () {
    test('the screen’s controller reads the ledger, the person, the chapters and the bell once', () async {
      final repo = FakeVolunteer(unread: 2);
      final c = VolunteerController(repo);
      await Future.wait([c.start(), c.start()]);
      expect(repo.count('cpd'), 1);
      expect(c.cpd!.totalHours, 12);
      expect(c.signedIn, isTrue);
      expect(c.sender!.name, 'Nikhil Majjagi');
      expect(c.chapters, hasLength(4));
      expect(c.unread, 2);
    });

    test('signed out there is no ledger and no sender; a failed ledger is said and the rest stands', () async {
      final out = FakeVolunteer()..signedOut = true;
      final c = VolunteerController(out);
      await c.start();
      expect(c.cpd, isNull);
      expect(c.signedIn, isFalse);
      expect(c.cpdError, isNull);

      final broken = FakeVolunteer()..failures['cpd'] = ApiError('The ledger is down.', statusCode: 500);
      final d = VolunteerController(broken);
      await d.start();
      expect(d.cpdError, 'The ledger is down.');
      expect(d.chapters, hasLength(4));
      broken.failures.clear();
      await d.refresh();
      expect(d.cpdError, isNull);
      expect(d.cpd!.totalHours, 12);
    });

    test(
      'the search narrows the roles, a role opens and closes, and interest sent is remembered for the visit',
      () async {
        final c = VolunteerController(FakeVolunteer());
        await c.start();
        expect(c.visibleRoles, hasLength(20));
        c.setSearch('  mentor ');
        expect(c.visibleRoles.map((r) => r.key), contains('mentor'));
        expect(c.visibleRoles.length, lessThan(20));
        c.setSearch('zzzz');
        expect(c.visibleRoles, isEmpty);
        c.setSearch('');
        final r = c.roles.first;
        expect(c.isOpen(r), isFalse);
        c.toggle(r);
        expect(c.isOpen(r), isTrue);
        c.toggle(r);
        expect(c.isOpen(r), isFalse);
        expect(c.isSent(r), isFalse);
        c.markSent(r);
        c.markSent(null);
        expect(c.isSent(r), isTrue);
        expect(c.isSent(null), isTrue);
        expect(c.isSent(c.roles.last), isFalse);
        expect(c.roleByKey('mentor')!.title, 'Mentor or Coach');
        expect(c.roleByKey('nope'), isNull);
      },
    );

    test('the form starts from the person, and says what is wrong in the contact form’s own words', () async {
      final f = VolunteerFormController(
        repository: FakeVolunteer(),
        sender: const ContactSender(name: 'Nikhil Majjagi', email: 'nikhil@x.com', phone: '+9198'),
      );
      expect((f.name, f.email, f.phone), ('Nikhil Majjagi', 'nikhil@x.com', '+9198'));
      expect(f.problems.keys, [ContactField.message]);
      f.setName('');
      f.setEmail('not an email');
      f.setPhone('9' * 31);
      expect(f.problems[ContactField.name], 'Enter your name.');
      expect(f.problems[ContactField.email], 'Enter a valid email address.');
      expect(f.problems[ContactField.phone], contains('30 characters or fewer'));
      expect(f.problemFor(ContactField.name), isNull, reason: 'nothing is shown before a send was tried');
      expect(await f.submit(), isFalse);
      expect(f.problemFor(ContactField.name), 'Enter your name.');
      f.setName('N');
      f.setEmail('n@x.com');
      f.setPhone('');
      f.setMessage('Hi');
      expect(f.problems, isEmpty);
    });

    test('a message longer than what is left of 4,000 after the role and chapter lines is refused', () async {
      final f = VolunteerFormController(
        repository: FakeVolunteer(),
        roles: volunteerRoles,
        role: volunteerRoles.first,
        chapterName: 'ICR Bengaluru Chapter',
        sender: const ContactSender(name: 'N', email: 'n@x.com'),
      );
      final room = f.messageRoom;
      expect(room, lessThan(4000));
      f.setMessage('x' * room);
      expect(f.problems, isEmpty);
      f.setMessage('x' * (room + 1));
      expect(f.problems[ContactField.message], 'Use $room characters or fewer here.');
    });

    test('sending keeps the form on a refusal and says it was sent on success', () async {
      final repo = FakeVolunteer()
        ..failures['apply'] = ApiError('Too many requests. Wait a minute and try again.', statusCode: 429);
      final f = VolunteerFormController(
        repository: repo,
        role: volunteerRoles.first,
        sender: const ContactSender(name: 'N', email: 'n@x.com'),
      )..setMessage('I can help.');
      expect(await f.submit(), isFalse);
      expect(f.error, 'Too many requests. Wait a minute and try again.');
      expect(f.message, 'I can help.');
      expect(f.sent, isFalse);
      expect(f.busy, isFalse);
      repo.failures.clear();
      expect(await f.submit(), isTrue);
      expect(f.sent, isTrue);
      expect(repo.sent.single.role!.key, 'chapter-committee-member');
      expect(repo.sent.single.message, 'I can help.');
    });
  });

  group('the Get Involved screen', () {
    testWidgets('draws the headline, the member’s CPD from the API, the opportunities and the benefits', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Get Involved'), findsOneWidget);
      expect(find.text('GET INVOLVED & VOLUNTEER'), findsOneWidget);
      expect(find.text('Volunteer, lead, shape the profession'), findsOneWidget);
      // The ledger the API holds: 12 hours, 8.5 this year of a 15-hour target, by source, the latest entries.
      expect(find.text('Your CPD'), findsOneWidget);
      expect(find.text('Hours earned'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('In 2026'), findsOneWidget);
      expect(find.text('8.5'), findsOneWidget);
      expect(find.text('of 15'), findsOneWidget);
      expect(find.text('57% of your 15-hour target'), findsOneWidget);
      expect(find.text('Course 6.5 h'), findsOneWidget);
      expect(find.text('Event 3.5 h'), findsOneWidget);
      expect(find.text('Mentoring 2 h'), findsOneWidget);
      expect(find.text('Course · Facility Management Essentials'), findsOneWidget);
      expect(find.text('Volunteer Opportunities'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('Chapter Committee Member'), findsOneWidget);
      expect(find.text('Community Ambassador'), findsOneWidget);
      expect(find.text('Volunteer Benefits'), findsOneWidget);
      expect(find.text('Leadership experience'), findsOneWidget);
      expect(find.text('Volunteering earns CPD credits'), findsOneWidget);
      expect(find.text('Mentoring: 12 credits'), findsOneWidget);
    });

    testWidgets('Back and the bell (the shell’s, or the website’s notifications page)', (tester) async {
      final page = await _pump(tester);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      expect(page.backs, 1);
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(page.opened.last, AppConfig.sitePage('/notifications'));
      final own = await _pump(tester, ownBell: true);
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(own.bells, 1);
      expect(own.opened, isEmpty);
    });

    testWidgets('the bell wears its dot while something is unread', (tester) async {
      await _pump(tester, repo: FakeVolunteer(unread: 3));
      expect(find.bySemanticsLabel('Notifications, 3 unread'), findsOneWidget);
    });

    testWidgets('Become a mentor and Find your chapter are the shell’s callbacks and are left out without one', (
      tester,
    ) async {
      final page = await _pump(tester);
      await tester.tap(find.text('Become a mentor'));
      await tester.tap(find.text('Find your chapter'));
      expect((page.mentors, page.chapters), (1, 1));
      await _pump(tester, mentor: false, chapters: false);
      expect(find.text('Become a mentor'), findsNothing);
      expect(find.text('Find your chapter'), findsNothing);
    });

    testWidgets('signed out, the CPD card says to sign in; a failed read says why and Try again reads it', (
      tester,
    ) async {
      await _pump(tester, repo: FakeVolunteer()..signedOut = true);
      expect(find.text('Sign in to see the CPD hours you have earned.'), findsOneWidget);
      expect(find.text('Hours earned'), findsNothing);

      final repo = FakeVolunteer()..failures['cpd'] = ApiError('The ledger is down.', statusCode: 500);
      await _pump(tester, repo: repo);
      expect(find.text('The ledger is down.'), findsOneWidget);
      repo.failures.clear();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Hours earned'), findsOneWidget);
    });

    testWidgets('a suggested target (the API’s default) is called that', (tester) async {
      final inner = DemoVolunteerRepository();
      final repo = _DefaultTarget(inner);
      await _pump(tester, repo: repo);
      expect(find.text('57% of the suggested 15 hours'), findsOneWidget);
    });

    testWidgets('the search narrows the roles as typed, says when none match, and Clear search brings them back', (
      tester,
    ) async {
      await _pump(tester);
      await tester.enterText(find.byType(TextField), 'mentor');
      await tester.pumpAndSettle();
      final expected = volunteerRoles.where((r) => r.matches('mentor')).length;
      expect(find.byType(Card), findsNothing);
      expect(find.text('Mentor or Coach'), findsOneWidget);
      expect(find.text('Chapter Committee Member'), findsNothing);
      expect(expected, greaterThan(1));
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('No role matches'), findsOneWidget);
      await tester.tap(find.text('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Chapter Committee Member'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    });

    testWidgets('Responsibilities open to the four duties and close again', (tester) async {
      await _pump(tester);
      expect(find.text('Attend and contribute to chapter committee meetings'), findsNothing);
      await tester.tap(find.text('Responsibilities').first);
      await tester.pumpAndSettle();
      expect(find.text('Attend and contribute to chapter committee meetings'), findsOneWidget);
      expect(find.text('Represent member interests to the chapter leadership'), findsOneWidget);
      await tester.tap(find.text('Responsibilities').first);
      await tester.pumpAndSettle();
      expect(find.text('Attend and contribute to chapter committee meetings'), findsNothing);
    });

    testWidgets(
      'Apply opens the form on that role with its time, and sending reaches the team; the card then says so',
      (tester) async {
        final page = await _pump(tester);
        await tester.tap(find.text('Apply').first);
        await tester.pumpAndSettle();
        expect(find.byType(VolunteerApplyScreen), findsOneWidget);
        expect(find.text('Chapter Committee Member'), findsWidgets);
        expect(find.text('4–6 hours per month'), findsWidgets);
        // Name and email come from the account.
        expect(tester.widget<TextField>(_field('volunteer-name')).controller!.text, 'Nikhil Majjagi');
        expect(tester.widget<TextField>(_field('volunteer-email')).controller!.text, 'nikhil@techcorp.example');
        await tester.enterText(_field('volunteer-message'), 'I lead facilities at a GCC campus.');
        await tester.pump();
        await tester.tap(find.text('Send to the ICR team'));
        await tester.pumpAndSettle();
        expect(find.text('Thank you, Nikhil'), findsOneWidget);
        expect(find.textContaining('Your interest in Chapter Committee Member reached the ICR team.'), findsOneWidget);
        expect(find.textContaining('They will write to nikhil@techcorp.example.'), findsOneWidget);
        expect(page.repo.sent.single.role!.key, 'chapter-committee-member');
        expect(page.repo.sent.single.message, 'I lead facilities at a GCC campus.');

        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(find.byType(VolunteerApplyScreen), findsNothing);
        expect(find.text('Your interest is with the ICR team.'), findsOneWidget);
        expect(find.text('INTEREST SENT'), findsOneWidget);
        expect(find.text('Apply again'), findsOneWidget);
      },
    );

    testWidgets('the hero button and "Raise your hand" open the form with no role; the general one is remembered too', (
      tester,
    ) async {
      final page = await _pump(tester);
      await tester.tap(find.text('Volunteer with ICR').first);
      await tester.pumpAndSettle();
      expect(find.text('Not sure yet: any role'), findsOneWidget);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(VolunteerApplyScreen), findsNothing);
      await tester.ensureVisible(find.text('Raise your hand'));
      await tester.tap(find.text('Raise your hand'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('volunteer-message'), 'Wherever I am useful.');
      await tester.pump();
      await tester.tap(find.text('Send to the ICR team'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your interest in volunteering reached the ICR team.'), findsOneWidget);
      expect(page.repo.sent.single.role, isNull);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(page.controller.isSent(null), isTrue);
    });

    testWidgets('a chapter’s page opens the form on a committee seat at that chapter', (tester) async {
      final page = await _pump(tester, intent: const VolunteerIntent.chapter('ICR Bengaluru Chapter'));
      expect(find.byType(VolunteerApplyScreen), findsOneWidget);
      expect(find.text('Chapter Committee Member'), findsWidgets);
      expect(find.text('ICR Bengaluru Chapter'), findsOneWidget);
      // Reading who the member is happens once, not once for the screen and once for the form.
      expect(page.repo.count('sender'), 1);
      expect(tester.widget<TextField>(_field('volunteer-name')).controller!.text, 'Nikhil Majjagi');
    });

    testWidgets('pulling down reads the ledger and the bell again', (tester) async {
      final repo = FakeVolunteer();
      final page = await _pump(tester, repo: repo, height: 800);
      expect(repo.count('cpd'), 1);
      repo.unread = 2;
      await tester.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(repo.count('cpd'), 2);
      expect(page.controller.unread, 2);
    });
  });

  group('the application form', () {
    Future<_Page> openForm(WidgetTester tester, {FakeVolunteer? repo}) async {
      final page = await _pump(tester, repo: repo);
      await tester.tap(find.text('Volunteer with ICR').first);
      await tester.pumpAndSettle();
      return page;
    }

    testWidgets('the role and chapter pickers list what there is, "any" and "none" first, and a choice sticks', (
      tester,
    ) async {
      await openForm(tester);
      await tester.tap(find.text('Not sure yet: any role'));
      await tester.pumpAndSettle();
      expect(find.text('Which role?'), findsOneWidget);
      expect(find.text('Chapter Leader'), findsOneWidget);
      await tester.tap(find.text('Chapter Leader'));
      await tester.pumpAndSettle();
      expect(find.text('Chapter Leader'), findsOneWidget);
      expect(find.text('8–10 hours per month'), findsOneWidget);

      await tester.tap(find.text('No chapter in particular'));
      await tester.pumpAndSettle();
      expect(find.text('Which chapter?'), findsOneWidget);
      for (final c in [
        'ICR Bengaluru Chapter',
        'ICR Delhi NCR Chapter',
        'ICR Hyderabad Chapter',
        'ICR Mumbai Chapter',
      ]) {
        expect(find.text(c), findsOneWidget);
      }
      await tester.tap(find.text('ICR Mumbai Chapter'));
      await tester.pumpAndSettle();
      expect(find.text('ICR Mumbai Chapter'), findsOneWidget);
      expect(find.text('No chapter in particular'), findsNothing);

      // Back to none.
      await tester.tap(find.text('ICR Mumbai Chapter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No chapter in particular'));
      await tester.pumpAndSettle();
      expect(find.text('No chapter in particular'), findsOneWidget);
    });

    testWidgets('a send with nothing written, a bad email or no name says what is wrong and sends nothing', (
      tester,
    ) async {
      final repo = FakeVolunteer()..signedOut = true;
      await openForm(tester, repo: repo);
      await tester.tap(find.text('Send to the ICR team'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your name.'), findsOneWidget);
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Tell us a little about you and the time you can give.'), findsOneWidget);
      expect(repo.count('apply'), 0);

      await tester.enterText(_field('volunteer-name'), 'Asha');
      await tester.enterText(_field('volunteer-email'), 'asha@@x');
      await tester.pump();
      await tester.tap(find.text('Send to the ICR team'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(repo.count('apply'), 0);
    });

    testWidgets('a refusal is shown under the form, everything typed stays, and sending again works', (tester) async {
      final repo = FakeVolunteer()
        ..failures['apply'] = ApiError('Too many requests. Wait a minute and try again.', statusCode: 429);
      await openForm(tester, repo: repo);
      await tester.enterText(_field('volunteer-message'), 'I can help with ESG content.');
      await tester.enterText(_field('volunteer-phone'), '+91 98765 43210');
      await tester.pump();
      await tester.tap(find.text('Send to the ICR team'));
      await tester.pumpAndSettle();
      expect(find.text('Too many requests. Wait a minute and try again.'), findsOneWidget);
      expect(find.text('I can help with ESG content.'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.byType(VolunteerApplyScreen), findsOneWidget);
      repo.failures.clear();
      await tester.tap(find.text('Send to the ICR team'));
      await tester.pumpAndSettle();
      expect(find.text('Thank you, Nikhil'), findsOneWidget);
      expect(repo.sent.single.phone, '+91 98765 43210');
    });

    testWidgets('the message box allows what is left of 4,000 after the role and chapter lines', (tester) async {
      await openForm(tester);
      final before = tester.widget<TextField>(_field('volunteer-message')).maxLength!;
      await tester.tap(find.text('Not sure yet: any role'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chapter Leader'));
      await tester.pumpAndSettle();
      final after = tester.widget<TextField>(_field('volunteer-message')).maxLength!;
      expect(after, lessThan(before));
      expect(before, lessThan(4000));
    });

    testWidgets('Back from the form returns to the list without sending', (tester) async {
      final page = await _pump(tester);
      await tester.tap(find.text('Volunteer with ICR').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(VolunteerApplyScreen), findsNothing);
      expect(page.repo.count('apply'), 0);
      expect(page.controller.isSent(null), isFalse);
    });

    testWidgets('the form’s bell opens the website’s notifications page when the shell wired none', (tester) async {
      final repo = FakeVolunteer();
      final page = await _pump(tester, repo: repo);
      await tester.tap(find.text('Volunteer with ICR').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(page.opened.last, AppConfig.sitePage('/notifications'));
    });
  });
}

/// The sample source with the API's default target ("suggested", not the member's own).
class _DefaultTarget extends FakeVolunteer {
  _DefaultTarget(DemoVolunteerRepository inner) : super(inner: inner);

  @override
  Future<CpdSummary?> cpd() async {
    final base = (await super.cpd())!;
    return CpdSummary(
      totalHours: base.totalHours,
      hoursThisYear: base.hoursThisYear,
      bySource: base.bySource,
      recent: base.recent,
      year: base.year,
      targetHours: base.targetHours,
      progress: base.progress,
    );
  }
}
