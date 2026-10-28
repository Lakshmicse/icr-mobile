/// Get Involved & Volunteer against the LOCAL portal API: the app's own repository and controllers, the way
/// the screen uses them, with the effect read back through the API.
///
/// The one write is the application itself, which the API files as a contact message and a CRM lead (the
/// website's volunteer form is the contact form with topic VOLUNTEER). The test marks it, reads it back as
/// the ICR admin (Sana Admin, the e2e SUPER_ADMIN), and then undoes what the API lets it: the lead is
/// deleted and the message set to SPAM (a contact message cannot be deleted).
///
///     flutter test test/live/volunteer_live_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/volunteer/api_volunteer_repository.dart';
import 'package:icr_mobile/features/volunteer/volunteer_controller.dart';
import 'package:icr_mobile/features/volunteer/volunteer_data.dart';
import 'package:icr_mobile/features/volunteer/volunteer_models.dart';

import 'live.dart';

const _admin = LivePerson('superadmin@icr.test', 'Test@12345', 'Sana Admin');

Future<ApiVolunteerRepository> _repository([LivePerson who = bharat]) async =>
    ApiVolunteerRepository(api: await liveClient(who));

/// The contact message the application became, found by its marker, as the admin sees it.
Future<Map<String, dynamic>?> _inboxRow(ApiClient admin, String marker) async {
  final res = await admin.dio.get<Map<String, dynamic>>(
    '/contact',
    queryParameters: {'topic': 'VOLUNTEER', 'search': marker, 'limit': 5},
  );
  final rows = (res.data!['data'] as List).cast<Map<String, dynamic>>();
  return rows.isEmpty ? null : rows.first;
}

/// Takes the application back out as far as the API allows.
Future<void> _undo(ApiClient admin, Map<String, dynamic> row) async {
  final lead = (row['lead'] as Map?)?['id'] as String?;
  if (lead != null) await admin.dio.delete<dynamic>('/crm/leads/$lead');
  await admin.dio.patch<dynamic>('/contact/${row['id']}/status', data: {'status': 'SPAM'});
}

void main() {
  liveTest(
    'the CPD card is the member\'s own ledger: totals, sources, the latest entries and the year\'s target',
    () async {
      final repo = await _repository();
      final api = await liveClient();
      final summary = (await api.dio.get<Map<String, dynamic>>('/mentorship/cpd/summary')).data!;
      final target = (await api.dio.get<Map<String, dynamic>>('/mentorship/cpd/target')).data!;
      final cpd = (await repo.cpd())!;

      expect(cpd.totalHours, (summary['totalHours'] as num).toDouble());
      expect(cpd.hoursThisYear, (summary['hoursThisYear'] as num).toDouble());
      expect(cpd.bySource.map((s) => s.source), (summary['bySource'] as List).map((s) => (s as Map)['source']));
      expect(cpd.bySource.fold<double>(0, (n, s) => n + s.hours), closeTo(cpd.totalHours, 0.001));
      expect(cpd.recent.map((e) => e.id), (summary['recent'] as List).map((e) => (e as Map)['id']));
      expect(cpd.recent.every((e) => e.awardedAt != null && e.hours > 0), isTrue);
      expect(cpd.year, target['year']);
      expect(cpd.targetHours, (target['targetHours'] as num).toDouble());
      expect(cpd.progress, (target['progress'] as num?)?.toDouble());
      expect(cpd.targetIsDefault, target['isDefault']);
      // Every source the ledger names has a word.
      for (final s in cpd.bySource) {
        expect(CpdSummary.sourceLabels.containsKey(s.source), isTrue, reason: s.source);
      }
    },
  );

  liveTest('signed out there is no ledger and no sender, and the roles still read', () async {
    final signedOut = ApiVolunteerRepository(api: liveAnonymous());
    expect(await signedOut.cpd(), isNull);
    expect(await signedOut.sender(), isNull);
    final c = VolunteerController(signedOut);
    await c.start();
    expect(c.signedIn, isFalse);
    expect(c.cpd, isNull);
    expect(c.cpdError, isNull);
    expect(c.chapters, isNotEmpty, reason: 'the chapters are public');
    expect(c.visibleRoles, hasLength(volunteerRoles.length));
  });

  liveTest('the form starts from the signed-in person and offers every published chapter', () async {
    final repo = await _repository();
    final api = await liveClient();
    final me = (await api.dio.get<Map<String, dynamic>>('/auth/me')).data!;
    final sender = (await repo.sender())!;
    expect(sender.name, '${me['firstName']} ${me['lastName']}'.trim());
    expect(sender.email, me['email']);

    final raw = (await api.dio.get<Map<String, dynamic>>('/chapters', queryParameters: {'limit': 100})).data!;
    final names = (raw['data'] as List).map((c) => (c as Map)['name'] as String).toList()..sort();
    expect((await repo.chapters()).map((c) => c.name), names);
  });

  liveTest('the controller reads the ledger, the person, the chapters and the bell the way the screen does', () async {
    final c = VolunteerController(await _repository());
    await c.start();
    expect(c.cpdError, isNull);
    expect(c.signedIn, isTrue);
    expect(c.cpd, isNotNull);
    expect(c.sender!.email, 'buyer@icr.dev');
    expect(c.chapters.length, greaterThanOrEqualTo(4));
    final api = await liveClient();
    final unread = (await api.dio.get<Map<String, dynamic>>('/notifications/unread-count')).data!['unread'] as num;
    expect(c.unread, unread.toInt());
  });

  liveTest(
    'an application is a contact message with topic VOLUNTEER and a lead for the team; the admin sees it as sent',
    () async {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final marker = 'mobile-live-$stamp';
      final repo = await _repository();
      final role = volunteerRoles.firstWhere((r) => r.key == 'speaker');
      final admin = await liveClient(_admin);

      final form = VolunteerFormController(
        repository: repo,
        roles: volunteerRoles,
        chapters: await repo.chapters(),
        sender: await repo.sender(),
        role: role,
        chapterName: 'ICR Bengaluru Chapter',
      )..setMessage('Live test, please ignore: $marker');
      expect(form.problems, isEmpty);
      Map<String, dynamic>? row;
      try {
        expect(await form.submit(), isTrue);
        expect(form.sent, isTrue);

        row = await _inboxRow(admin, marker);
        expect(row, isNotNull, reason: 'the ICR inbox holds the application');
        expect(row!['topic'], 'VOLUNTEER');
        expect(row['status'], 'NEW');
        expect(row['name'], 'Bharat Buyer');
        expect(row['email'], 'buyer@icr.dev');
        final message = row['message'] as String;
        expect(message, startsWith('Volunteer application: Speaker or Panelist\n'));
        expect(message, contains('Commitment: ${role.commitment}'));
        expect(message, contains('Chapter: ICR Bengaluru Chapter'));
        expect(message, endsWith('Live test, please ignore: $marker'));
        expect((row['lead'] as Map?)?['stage'], 'NEW', reason: 'the API files a lead for the team');
      } finally {
        if (row != null) await _undo(admin, row);
      }
      final after = await _inboxRow(admin, marker);
      expect(after!['status'], 'SPAM');
      expect(after['lead'], isNull, reason: 'the lead was deleted');
    },
  );

  liveTest('the API refuses what the form should have caught, in its own words', () async {
    final repo = await _repository();
    await expectLater(
      repo.apply(const VolunteerApplication(name: 'Live Test', email: 'not-an-email', message: 'Please ignore')),
      throwsA(
        isA<ApiError>()
            .having((e) => e.statusCode, 'status', 400)
            .having((e) => e.message.toLowerCase(), 'message', contains('email')),
      ),
    );
    await expectLater(
      repo.apply(VolunteerApplication(name: 'x' * 121, email: 'a@b.co', message: 'Please ignore')),
      throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 400)),
    );
  });
}
