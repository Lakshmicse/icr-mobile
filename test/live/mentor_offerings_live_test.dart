/// The mentor desk's Offerings against the LOCAL API, as the seeded paid mentor
/// (Anand Iyer: a live storefront with services, a coaching plan, a programme and
/// group sessions; run `tool/seed/mentoring.ts` first). Every control that reads
/// or writes through the API is exercised through the panel's own repository and
/// controller and proved by reading the effect back; each test makes its own rows
/// and takes them away again (a service and a plan are deleted; a group session
/// has no delete in the API, so it is cancelled and `tool/seed/mentoring_offerings.ts
/// --remove` sweeps what is left). The seeded rows are only ever read.
///
///     flutter test test/live/mentor_offerings_live_test.dart --concurrency=1
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_controller.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_models.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_repository.dart';
import 'package:icr_mobile/features/mentor_desk/offerings/offerings_rules.dart';

import 'live.dart';

const _password = 'Password123!';
const anand = LivePerson('mentoring.anand@design.icr.test', _password, 'Anand Iyer (paid mentor)');
const divya = LivePerson('mentoring.divya@design.icr.test', _password, 'Divya Rao (free mentor)');

/// A PDF of a few lines: what a resource's file is, to the API.
Uint8List tinyPdf() =>
    Uint8List.fromList('%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n'.codeUnits);

/// A 1x1 PNG: what a cover is.
final tinyPng = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01, //
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Future<OfferingsRepository> repoFor(LivePerson who) async => OfferingsRepository(api: await liveClient(who));

Future<OfferingsController> loadedFor(LivePerson who) async {
  final c = OfferingsController(await repoFor(who));
  await c.start();
  return c;
}

/// Starts of a group session far enough ahead to clear anything on the mentor's calendar.
DateTime farAhead({int days = 45, int hour = 4}) {
  final d = DateTime.now().toUtc().add(Duration(days: days));
  return DateTime.utc(d.year, d.month, d.day, hour);
}

void main() {
  group('the Offerings panel reads the API\'s real answers (Anand)', () {
    liveTest(
      'the storefront, the plans and the group sessions parse, with the seeded rows as the seed made them',
      () async {
        final c = await loadedFor(anand);
        expect(c.storefront.error, isNull, reason: '${c.storefront.error}');
        final g = c.gates!;
        expect(g.live, isTrue);
        expect(g.optedIn, isTrue);
        expect(g.suspended, isFalse);
        expect(g.termsCurrent, isTrue);
        expect(g.termsCurrentVersion, isNotEmpty);
        expect(g.blockedReason, isNull);

        final byId = {for (final s in c.services) s.id: s};
        final strategy = byId['dsgn-mentoring-svc-strategy']!;
        expect(strategy.kind, ServiceKind.oneOnOne);
        expect(strategy.pricePaisa, 149900);
        expect(strategy.compareAtPaisa, 199900);
        expect(strategy.durationMin, 45);
        expect(strategy.active, isTrue);
        expect(strategy.salesCount, greaterThan(0));
        final kit = byId['dsgn-mentoring-svc-kit']!;
        expect(kit.kind, ServiceKind.resource);
        expect(kit.fileName, 'interview-question-bank');
        expect(kit.fileSize, 705);
        expect(kit.blocker, isNull);
        final workbook = byId['dsgn-mentoring-svc-workbook']!;
        expect(workbook.free, isTrue);
        final draft = byId['dsgn-mentoring-svc-draft']!;
        expect(draft.active, isFalse);
        expect(
          c.singles.map((s) => s.id),
          containsAll(['dsgn-mentoring-svc-discovery', 'dsgn-mentoring-svc-strategy']),
        );
        expect(c.resources.map((s) => s.id), containsAll(['dsgn-mentoring-svc-kit', 'dsgn-mentoring-svc-workbook']));
        expect(c.listingsUsed, greaterThanOrEqualTo(6));

        expect(c.plans.error, isNull, reason: '${c.plans.error}');
        final coaching = c.ongoing.firstWhere((p) => p.id == 'dsgn-mentoring-plan-coaching');
        expect(coaching.programme, isFalse);
        expect(coaching.pricePaisa, 299900);
        expect(coaching.sessionsPerMonth, 2);
        expect(coaching.billingPeriodMonths, 1);
        expect(coaching.sessionDurationMin, 45);
        expect(coaching.inclusions, hasLength(3));
        final programme = c.programmes.firstWhere((p) => p.id == 'dsgn-mentoring-plan-programme');
        expect(programme.programme, isTrue);
        expect(programme.pricePaisa, 599900);
        expect(programme.totalSessions, 3);
        expect(programme.accessMonths, 3);
        expect(programme.steps.map((s) => s.title).first, 'Where you are, where you want to be');
        expect(programme.steps.map((s) => s.position), [1, 2, 3]);

        expect(c.sessions.error, isNull, reason: '${c.sessions.error}');
        final sessions = {for (final s in c.sessions.data!) s.id: s};
        expect(sessions['dsgn-mentoring-group-draft']!.draft, isTrue);
        expect(sessions['dsgn-mentoring-group-clinic']!.scheduled, isTrue);
        expect(sessions['dsgn-mentoring-group-clinic']!.seatsTaken, 3);
        expect(sessions['dsgn-mentoring-group-clinic']!.capacity, 25);
        expect(sessions['dsgn-mentoring-group-paid']!.pricePaisa, 29900);
        expect(sessions['dsgn-mentoring-group-paid']!.paid, isTrue);
        expect(sessions['dsgn-mentoring-group-past']!.completed, isTrue);
        expect(sessions['dsgn-mentoring-group-clinic']!.days, isNotEmpty);
        expect(sessions['dsgn-mentoring-group-clinic']!.roster, isNull, reason: 'the list holds no roster');
      },
    );

    liveTest('a session\'s detail carries the host\'s roster, with each person\'s question', () async {
      final c = await loadedFor(anand);
      final clinic = c.sessions.data!.firstWhere((s) => s.id == 'dsgn-mentoring-group-clinic');
      final d = await c.detail(clinic);
      expect(d.roster, isNotNull);
      expect(d.roster!.map((r) => r.name), containsAll(['Meera Nair', 'Tanvi Joshi']));
      final meera = d.roster!.firstWhere((r) => r.name == 'Meera Nair');
      expect(meera.question, 'How do I present a portfolio case to finance?');
      expect(meera.status, 'REGISTERED');
      expect(meera.holdsSeat, isTrue);
      expect(meera.id, isNotEmpty, reason: 'the attendee row id: what attendance is recorded against');
      expect(d.meetingLink, isNotNull);
      expect(d.coverUrl, anyOf(isNull, isA<String>()));
      expect(d.timezone, 'Asia/Kolkata');
      expect(d.agendaHtml, anyOf(isNull, isA<String>()));
      final past = await c.detail(c.sessions.data!.firstWhere((s) => s.id == 'dsgn-mentoring-group-past'));
      expect(past.roster!.map((r) => r.status), contains('ATTENDED'));
      expect(past.completed, isTrue);
    });

    liveTest(
      'a mentor with no seller terms sees the API\'s own gate, and cannot open the storefront with a wrong version',
      () async {
        final repo = await repoFor(divya);
        final s = await repo.storefront();
        expect(s.gates.live, isFalse);
        expect(s.gates.optedIn, isFalse);
        expect(s.gates.blockedReason, 'Accept the seller terms to open your storefront.');
        expect(s.gates.termsAreTheBlocker, isTrue);
        await expectLater(
          repo.acceptTerms('1999.0'),
          throwsA(predicate((e) => e.toString().contains('That is not the current seller terms version'))),
        );
        // Selling is refused in the gate's own words, before any field is judged.
        await expectLater(
          repo.createService({'type': 'ONE_ON_ONE', 'title': 'Divya\'s call', 'pricePaisa': 0, 'durationMin': 30}),
          throwsA(predicate((e) => e.toString() == 'Accept the seller terms to open your storefront.')),
        );
        await expectLater(
          repo.createPlan({'title': 'Divya\'s plan', 'kind': 'RECURRING', 'pricePaisa': 0, 'sessionsPerMonth': 1}),
          throwsA(predicate((e) => e.toString() == 'Accept the marketplace seller terms first.')),
        );
        final after = await repo.storefront();
        expect(after.gates.optedIn, isFalse, reason: 'nothing changed');
      },
    );
  });

  group('services: a mentor lists, edits, pauses and deletes their own', () {
    liveTest(
      'a 1:1 session is created, edited, paused, resumed and deleted; the API\'s rules answer in its own words',
      () async {
        final c = await loadedFor(anand);
        final repo = c.repository;
        final created = <String>[];
        try {
          // The rules a form checks first, as the API words them.
          Future<String> refusal(Map<String, Object?> body) async {
            final r = await c.saveService({
              'type': 'ONE_ON_ONE',
              'title': 'Live test call',
              'pricePaisa': 59900,
              'durationMin': 30,
              ...body,
            });
            return r ?? 'no refusal';
          }

          expect(await refusal({'pricePaisa': 10000}), 'Priced services start at ₹499.');
          expect(await refusal({'compareAtPaisa': 59900}), 'The compare-at price must be higher than the price.');
          expect(await refusal({'compareAtPaisa': 150000}), 'Discounts are capped at 50% — credibility beats theatre.');
          expect(await refusal({'durationMin': null}), 'A 1:1 call needs a duration.');
          expect(await refusal({'title': 'abc'}), isNot('no refusal'), reason: 'a title is 4 characters at least');
          expect(await refusal({'durationMin': 5}), isNot('no refusal'));
          expect(await refusal({'type': 'QUERY'}), 'Written consultations are no longer sold.');
          expect(await refusal({'pricePaisa': 6000000}), isNot('no refusal'), reason: 'at most ₹50,000');
          // The same checks, in the app's own rules, agree with the API on each of these.
          expect(servicePriceProblem(free: false, price: '100', compareAt: ''), 'Priced services start at ₹499.');
          expect(
            servicePriceProblem(free: false, price: '599', compareAt: '599'),
            'The compare-at price must be higher than the price.',
          );
          expect(
            servicePriceProblem(free: false, price: '599', compareAt: '1500'),
            startsWith('Discounts are capped at 50%'),
          );

          // Add (paused, so nothing is shown to members), then read it back.
          expect(
            await c.saveService({
              'type': 'ONE_ON_ONE',
              'title': 'Live test call',
              'blurb': 'A test call.',
              'pricePaisa': 59900,
              'compareAtPaisa': 79900,
              'durationMin': 30,
              'active': false,
            }),
            isNull,
          );
          final row = c.services.firstWhere((s) => s.title == 'Live test call');
          created.add(row.id);
          expect(row.kind, ServiceKind.oneOnOne);
          expect(row.pricePaisa, 59900);
          expect(row.compareAtPaisa, 79900);
          expect(row.durationMin, 30);
          expect(row.blurb, 'A test call.');
          expect(row.active, isFalse);
          expect(c.listingsUsed, greaterThanOrEqualTo(7));

          // Edit: the whole shape goes back, and a cleared strikethrough clears.
          expect(
            await c.saveService({
              'type': 'ONE_ON_ONE',
              'title': 'Live test call, edited',
              'pricePaisa': 64900,
              'compareAtPaisa': null,
              'durationMin': 45,
              'active': false,
            }, id: row.id),
            isNull,
          );
          var back = c.services.firstWhere((s) => s.id == row.id);
          expect(back.title, 'Live test call, edited');
          expect(back.pricePaisa, 64900);
          expect(back.compareAtPaisa, isNull);
          expect(back.durationMin, 45);
          expect(back.blurb, isNull, reason: 'an edit replaces what it does not send');

          // Pause and resume send the whole row back with only `active` changed.
          expect(await c.setServiceActive(back, true), isNull);
          back = c.services.firstWhere((s) => s.id == row.id);
          expect(back.active, isTrue);
          expect(back.title, 'Live test call, edited');
          expect(back.pricePaisa, 64900);
          expect(await c.setServiceActive(back, false), isNull);
          expect(c.services.firstWhere((s) => s.id == row.id).active, isFalse);

          // A service cannot change its type.
          await expectLater(
            repo.updateService(row.id, {
              'type': 'RESOURCE',
              'title': 'Live test call, edited',
              'pricePaisa': 0,
              'active': false,
            }),
            throwsA(predicate((e) => e.toString() == 'A service cannot change type — retire it and list a new one.')),
          );

          expect(await c.deleteService(back), isNull);
          created.remove(row.id);
          expect(c.services.any((s) => s.id == row.id), isFalse);
          expect(await c.deleteService(back), 'Service not found', reason: 'a deleted row is gone');
        } finally {
          for (final id in created) {
            try {
              await repo.deleteService(id);
            } on Object {
              // already gone
            }
          }
        }
      },
    );

    liveTest(
      'a resource needs its file: uploaded for mentor-resource, saved by its stored name, paused; resuming it wants the file again',
      () async {
        final c = await loadedFor(anand);
        final repo = c.repository;
        final created = <String>[];
        try {
          // No file: refused in the API's words (a paused one is fine).
          expect(
            await c.saveService({'type': 'RESOURCE', 'title': 'Live test guide', 'pricePaisa': 0, 'active': true}),
            fileNeededMessage,
          );
          // A type the upload refuses never becomes a file.
          await expectLater(
            repo.upload(
              PickedUpload(bytes: Uint8List.fromList([80, 75, 3, 4]), name: 'x.zip', mimeType: 'application/zip'),
              purpose: 'mentor-resource',
            ),
            throwsA(predicate((e) => e.toString().contains('is not an accepted file type'))),
          );
          final stored = await repo.upload(
            PickedUpload(bytes: tinyPdf(), name: 'live-test-guide.pdf', mimeType: 'application/pdf'),
            purpose: 'mentor-resource',
          );
          expect(stored.url, startsWith('/uploads/'));
          expect(stored.name, 'live-test-guide.pdf');
          expect(stored.size, tinyPdf().length);
          expect(stored.uploadId, isNot(contains('/')));

          expect(
            await c.saveService({
              'type': 'RESOURCE',
              'title': 'Live test guide',
              'pricePaisa': 0,
              'uploadId': stored.uploadId,
              'fileName': stored.name,
              'fileSize': stored.size,
              'active': true,
            }),
            isNull,
          );
          final row = c.services.firstWhere((s) => s.title == 'Live test guide');
          created.add(row.id);
          expect(row.kind, ServiceKind.resource);
          expect(row.fileName, 'live-test-guide.pdf');
          expect(row.fileSize, stored.size);
          expect(row.active, isTrue);
          expect(row.blocker, isNull);
          expect(row.durationMin, isNull);

          // Pausing needs no file...
          expect(await c.setServiceActive(row, false), isNull);
          final paused = c.services.firstWhere((s) => s.id == row.id);
          expect(paused.active, isFalse);
          expect(paused.fileName, 'live-test-guide.pdf', reason: 'the file is kept');
          // ... but the API will not publish a resource without the file in the same call, which is why the app
          // opens the form to choose it again (docs/backend-requests/mentor_offerings.md asks for the fix).
          expect(await c.setServiceActive(paused, true), fileNeededMessage);
          expect(
            await c.saveService({
              'type': 'RESOURCE',
              'title': 'Live test guide',
              'pricePaisa': 0,
              'uploadId': stored.uploadId,
              'fileName': stored.name,
              'fileSize': stored.size,
              'active': true,
            }, id: row.id),
            isNull,
          );
          expect(c.services.firstWhere((s) => s.id == row.id).active, isTrue);
        } finally {
          for (final id in created) {
            try {
              await repo.deleteService(id);
            } on Object {
              // already gone
            }
          }
        }
      },
    );

    liveTest('a cover is uploaded for mentor-offering, shown on the service, and taken off again', () async {
      final c = await loadedFor(anand);
      final repo = c.repository;
      final created = <String>[];
      try {
        final cover = await repo.upload(
          PickedUpload(bytes: tinyPng, name: 'cover.png', mimeType: 'image/png'),
          purpose: 'mentor-offering',
        );
        expect(
          await c.saveService({
            'type': 'ONE_ON_ONE',
            'title': 'Live test cover call',
            'pricePaisa': 0,
            'durationMin': 30,
            'active': false,
            'coverUrl': cover.url,
          }),
          isNull,
        );
        final row = c.services.firstWhere((s) => s.title == 'Live test cover call');
        created.add(row.id);
        expect(row.coverUrl, cover.url);
        // An edit that does not name the cover keeps it; null takes it off.
        expect(
          await c.saveService({
            'type': 'ONE_ON_ONE',
            'title': 'Live test cover call',
            'pricePaisa': 0,
            'durationMin': 30,
            'active': false,
          }, id: row.id),
          isNull,
        );
        expect(c.services.firstWhere((s) => s.id == row.id).coverUrl, cover.url);
        expect(
          await c.saveService({
            'type': 'ONE_ON_ONE',
            'title': 'Live test cover call',
            'pricePaisa': 0,
            'durationMin': 30,
            'active': false,
            'coverUrl': null,
          }, id: row.id),
          isNull,
        );
        expect(c.services.firstWhere((s) => s.id == row.id).coverUrl, isNull);
      } finally {
        for (final id in created) {
          try {
            await repo.deleteService(id);
          } on Object {
            // already gone
          }
        }
      }
    });

    liveTest('the listing cap is the API\'s: ten services, drafts included', () async {
      final c = await loadedFor(anand);
      final repo = c.repository;
      final created = <String>[];
      try {
        final room = maxServices - c.listingsUsed;
        for (var i = 0; i < room; i++) {
          expect(
            await c.saveService({
              'type': 'ONE_ON_ONE',
              'title': 'Live test filler $i',
              'pricePaisa': 0,
              'durationMin': 30,
              'active': false,
            }),
            isNull,
          );
          created.add(c.services.firstWhere((s) => s.title == 'Live test filler $i').id);
        }
        expect(c.listingsUsed, maxServices);
        expect(
          await c.saveService({
            'type': 'ONE_ON_ONE',
            'title': 'One too many',
            'pricePaisa': 0,
            'durationMin': 30,
            'active': false,
          }),
          'You can list up to 10 services — retire one first.',
        );
      } finally {
        for (final id in created) {
          try {
            await repo.deleteService(id);
          } on Object {
            // already gone
          }
        }
      }
      await c.storefront.load();
      expect(c.services.any((s) => s.title.startsWith('Live test filler')), isFalse);
    });
  });

  group('plans and programmes', () {
    liveTest(
      'an ongoing plan: the API\'s price and shape rules in its words, then created, edited, paused and deleted',
      () async {
        final c = await loadedFor(anand);
        final repo = c.repository;
        final created = <String>[];
        try {
          Future<String> refusal(Map<String, Object?> body) async =>
              await c.savePlan({
                'title': 'Live test plan',
                'kind': 'RECURRING',
                'pricePaisa': 299900,
                'sessionsPerMonth': 2,
                ...body,
              }) ??
              'no refusal';

          expect(
            await refusal({'pricePaisa': 49900}),
            'An ongoing plan is either free, or priced between ₹500 and ₹5,00,000 per term.',
          );
          expect(
            await refusal({'pricePaisa': 50000001}),
            'An ongoing plan is either free, or priced between ₹500 and ₹5,00,000 per term.',
          );
          expect(
            await refusal({'compareAtPaisa': 299900}),
            'The strikethrough price has to be higher than the price you are charging.',
          );
          expect(await refusal({'sessionsPerMonth': null}), 'Say how many sessions a month this plan includes.');
          expect(
            await refusal({
              'modules': [
                {'title': 'One'},
                {'title': 'Two'},
              ],
            }),
            'An ongoing plan has no fixed syllabus. Publish it as a structured program instead.',
          );
          expect(await refusal({'title': 'ab'}), isNot('no refusal'), reason: 'a title is 3 characters at least');
          expect(
            await refusal({'billingPeriodMonths': 2}),
            isNot('no refusal'),
            reason: 'a term is 1, 3, 6 or 12 months',
          );
          expect(
            recurringPriceProblem(free: false, price: '499', compareAt: ''),
            'An ongoing plan is either free, or priced between ₹500 and ₹5,00,000 per term.',
          );

          expect(
            await c.savePlan({
              'title': 'Live test plan',
              'blurb': 'A test plan.',
              'kind': 'RECURRING',
              'pricePaisa': 299900,
              'compareAtPaisa': 349900,
              'billingPeriodMonths': 3,
              'sessionsPerMonth': 2,
              'sessionDurationMin': 45,
              'inclusions': ['Two calls a month', 'Chat in between'],
              'active': false,
            }),
            isNull,
          );
          final row = c.ongoing.firstWhere((p) => p.title == 'Live test plan');
          created.add(row.id);
          expect(row.programme, isFalse);
          expect(row.pricePaisa, 299900);
          expect(row.compareAtPaisa, 349900);
          expect(row.billingPeriodMonths, 3);
          expect(row.sessionsPerMonth, 2);
          expect(row.sessionDurationMin, 45);
          expect(row.inclusions, ['Two calls a month', 'Chat in between']);
          expect(row.active, isFalse);
          expect(row.subscribersCount, 0);

          // A partial patch: what is not sent is kept; null clears the strikethrough.
          expect(
            await c.savePlan({
              'sessionsPerMonth': 4,
              'compareAtPaisa': null,
              'title': 'Live test plan, edited',
            }, id: row.id),
            isNull,
          );
          var back = c.ongoing.firstWhere((p) => p.id == row.id);
          expect(back.title, 'Live test plan, edited');
          expect(back.sessionsPerMonth, 4);
          expect(back.compareAtPaisa, isNull);
          expect(back.inclusions, ['Two calls a month', 'Chat in between'], reason: 'kept');
          expect(back.billingPeriodMonths, 3);

          // Pause and resume send `active` alone.
          expect(await c.setPlanActive(back, true), isNull);
          expect(c.ongoing.firstWhere((p) => p.id == row.id).active, isTrue);
          back = c.ongoing.firstWhere((p) => p.id == row.id);
          expect(back.title, 'Live test plan, edited');
          expect(await c.setPlanActive(back, false), isNull);
          expect(c.ongoing.firstWhere((p) => p.id == row.id).active, isFalse);

          // The kind is fixed.
          await expectLater(
            repo.updatePlan(row.id, {'kind': 'CURRICULUM'}),
            throwsA(
              predicate(
                (e) => e.toString().startsWith('A plan cannot change between an ongoing plan and a structured program'),
              ),
            ),
          );

          expect(await c.deletePlan(back), isNull);
          created.remove(row.id);
          expect(c.ongoing.any((p) => p.id == row.id), isFalse);
        } finally {
          for (final id in created) {
            try {
              await repo.deletePlan(id);
            } on Object {
              // already gone
            }
          }
        }
      },
    );

    liveTest(
      'a programme: its syllabus (2 to 24 sessions), the ₹499 floor and the discount cap, then created, re-sequenced, paused and deleted',
      () async {
        final c = await loadedFor(anand);
        final repo = c.repository;
        final created = <String>[];
        try {
          Map<String, Object?> body(Map<String, Object?> over) => {
            'title': 'Live test programme',
            'kind': 'CURRICULUM',
            'pricePaisa': 599900,
            'accessMonths': 3,
            'modules': [
              {'title': 'Where you are', 'outline': 'Scope and gaps', 'durationMin': 60},
              {'title': 'The business case'},
            ],
            'active': false,
            ...over,
          };
          Future<String> refusal(Map<String, Object?> over) async => await c.savePlan(body(over)) ?? 'no refusal';

          expect(await refusal({'pricePaisa': 30000}), '1:1 mentoring is either free or priced at ₹499 or more.');
          expect(
            await refusal({'pricePaisa': 100000, 'compareAtPaisa': 250000}),
            'A discount can be at most 50% off the strikethrough price.',
          );
          expect(
            await refusal({'compareAtPaisa': 599900}),
            'The strikethrough price has to be higher than the price you are charging.',
          );
          expect(
            await refusal({
              'modules': [
                {'title': 'Only one'},
              ],
            }),
            isNot('no refusal'),
            reason: 'at least 2 sessions',
          );
          expect(
            await refusal({
              'modules': [
                for (var i = 0; i < 25; i++) {'title': 'Session $i'},
              ],
            }),
            isNot('no refusal'),
            reason: 'at most 24',
          );
          expect(
            await refusal({
              'modules': [
                {'title': 'One'},
                {'title': 'ab'},
              ],
            }),
            isNot('no refusal'),
            reason: 'a session title is 3 characters at least',
          );
          expect(await refusal({'accessMonths': 30}), isNot('no refusal'), reason: 'access is 1 to 24 months');
          expect(
            programmePriceProblem(free: false, price: '300', compareAt: ''),
            '1:1 mentoring is either free or priced at ₹499 or more.',
          );
          expect(modulesProblem([ModuleDraft(title: 'One')]), 'A structured program runs between 2 and 24 sessions.');

          expect(
            await c.savePlan(
              body({
                'blurb': 'A test programme.',
                'inclusions': ['Notes after every session'],
                'sessionDurationMin': 60,
              }),
            ),
            isNull,
          );
          final row = c.programmes.firstWhere((p) => p.title == 'Live test programme');
          created.add(row.id);
          expect(row.programme, isTrue);
          expect(row.totalSessions, 2);
          expect(row.accessMonths, 3);
          expect(row.sessionsPerMonth, 0, reason: 'a programme has no monthly cadence');
          expect(row.steps.map((s) => s.title), ['Where you are', 'The business case']);
          expect(row.steps.first.outline, 'Scope and gaps');
          expect(row.steps.first.durationMin, 60);
          expect(row.steps.map((s) => s.position), [1, 2]);

          // The syllabus is replaced wholesale, and numbered from its order.
          expect(
            await c.savePlan({
              'modules': [
                {'title': 'The business case'},
                {'title': 'Where you are'},
                {'title': 'Vendor governance', 'durationMin': 90},
              ],
            }, id: row.id),
            isNull,
          );
          var back = c.programmes.firstWhere((p) => p.id == row.id);
          expect(back.steps.map((s) => s.title), ['The business case', 'Where you are', 'Vendor governance']);
          expect(back.steps.map((s) => s.position), [1, 2, 3]);
          expect(back.totalSessions, 3);
          expect(back.steps.last.durationMin, 90);

          // Editing only the title leaves the syllabus alone.
          expect(await c.savePlan({'title': 'Live test programme, edited'}, id: row.id), isNull);
          back = c.programmes.firstWhere((p) => p.id == row.id);
          expect(back.steps, hasLength(3));
          expect(back.title, 'Live test programme, edited');

          expect(await c.setPlanActive(back, true), isNull);
          expect(c.programmes.firstWhere((p) => p.id == row.id).active, isTrue);
          expect(await c.setPlanActive(back, false), isNull);
          expect(await c.deletePlan(back), isNull);
          created.remove(row.id);
          expect(c.programmes.any((p) => p.id == row.id), isFalse);
        } finally {
          for (final id in created) {
            try {
              await repo.deletePlan(id);
            } on Object {
              // already gone
            }
          }
        }
      },
    );
  });

  group('group sessions', () {
    liveTest(
      'a session is hosted as a draft, edited (what the API would blank is sent back), priced, published, and cancelled',
      () async {
        final c = await loadedFor(anand);
        final repo = c.repository;
        final start = farAhead();
        var id = '';
        try {
          Future<String> refusal(Map<String, Object?> over) async =>
              await c.saveSession({
                'title': 'Live test clinic',
                'mode': 'VIDEO',
                'meetingLink': 'https://meet.google.com/abc-defg-hij',
                'occurrences': [
                  {'scheduledAt': start.toIso8601String(), 'durationMin': 60},
                ],
                'capacity': 20,
                'pricePaisa': null,
                ...over,
              }) ??
              'no refusal';

          // The rules, in the API's words. None of these writes anything.
          expect(
            await refusal({
              'occurrences': [
                {
                  'scheduledAt': DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String(),
                  'durationMin': 60,
                },
              ],
            }),
            'Pick a time in the future.',
          );
          expect(
            await refusal({
              'occurrences': [
                {'scheduledAt': start.toIso8601String(), 'durationMin': 60},
                {'scheduledAt': start.add(const Duration(minutes: 30)).toIso8601String(), 'durationMin': 60},
              ],
            }),
            'Days must not overlap.',
          );
          expect(await refusal({'mode': 'IN_PERSON', 'meetingLink': null}), 'Add the venue where people will meet.');
          // (A blank joining link is not probed here: the mentor's standing link stands in for it, so the API would
          // take it and make a draft, which cannot be deleted.)
          expect(await refusal({'pricePaisa': 49900, 'capacity': null}), 'A paid session needs a number of seats.');
          expect(
            await refusal({'pricePaisa': 10000, 'capacity': 10}),
            isNot('no refusal'),
            reason: 'a seat is free or at least ₹499',
          );
          expect(await refusal({'capacity': 1}), isNot('no refusal'), reason: 'seats are 2 to 50');
          expect(await refusal({'title': 'abcd'}), isNot('no refusal'), reason: 'a title is 5 characters at least');
          expect(groupPlaceProblem(inPerson: true, location: '', link: ''), 'Add the venue where people will meet.');
          expect(
            daysProblem([(start, 60), (start.add(const Duration(minutes: 30)), 60)], DateTime.now()),
            'Days must not overlap.',
          );

          // Host it as a draft.
          expect(
            await c.saveSession({
              'title': 'Live test clinic under test',
              'summary': 'A test clinic.',
              'agendaHtml': agendaHtmlOf('Bring a real case.\n\nWe start with scope.'),
              'mode': 'VIDEO',
              'meetingLink': 'https://meet.google.com/abc-defg-hij',
              'occurrences': [
                {'scheduledAt': start.toIso8601String(), 'durationMin': 60},
              ],
              'capacity': 20,
              'pricePaisa': null,
              'waitlistEnabled': true,
            }),
            isNull,
          );
          final row = c.sessions.data!.firstWhere((s) => s.title == 'Live test clinic under test');
          id = row.id;
          expect(row.draft, isTrue);
          expect(row.capacity, 20);
          expect(row.paid, isFalse);
          expect(row.days.single.at.isAtSameMomentAs(start), isTrue);

          var d = await c.detail(row);
          expect(d.summary, 'A test clinic.');
          expect(agendaTextOf(d.agendaHtml), 'Bring a real case.\n\nWe start with scope.');
          expect(d.meetingLink, 'https://meet.google.com/abc-defg-hij');
          expect(d.roster, isEmpty);
          expect(d.timezone, isNotNull);

          // Edit: the form sends back what the API would otherwise blank.
          Map<String, Object?> editBody(HostedSession s, Map<String, Object?> over) => {
            'title': s.title,
            'summary': s.summary,
            'agendaHtml': s.agendaHtml,
            'mode': s.mode,
            'meetingLink': s.meetingLink,
            'occurrences': [
              for (final day in s.days)
                {'id': day.id, 'scheduledAt': day.at.toUtc().toIso8601String(), 'durationMin': day.durationMin},
            ],
            'capacity': s.capacity,
            'pricePaisa': s.pricePaisa,
            'coverUrl': s.coverUrl,
            if (s.timezone != null) 'timezone': s.timezone,
            ...over,
          };
          expect(
            await c.saveSession(editBody(d, {'title': 'Live test clinic under test, edited', 'capacity': 12}), id: id),
            isNull,
          );
          d = await c.detail(row);
          expect(d.title, 'Live test clinic under test, edited');
          expect(d.capacity, 12);
          expect(d.summary, 'A test clinic.', reason: 'sent back, so kept');
          expect(d.days.single.id, row.days.single.id, reason: 'the day keeps its id');
          expect(d.draft, isTrue);

          // Priced: free to paid is allowed while nobody has registered; a paid session needs seats and keeps no waitlist.
          expect(await c.saveSession(editBody(d, {'pricePaisa': 49900}), id: id), isNull);
          d = await c.detail(row);
          expect(d.pricePaisa, 49900);
          expect(d.paid, isTrue);
          expect(
            await c.saveSession(editBody(d, {'pricePaisa': 49900, 'capacity': null}), id: id),
            'A paid session needs a number of seats.',
          );
          expect(await c.saveSession(editBody(d, {'pricePaisa': null}), id: id), isNull);
          d = await c.detail(row);
          expect(d.paid, isFalse);

          // A series: a second day, in order, and back to one.
          expect(
            await c.saveSession(
              editBody(d, {
                'occurrences': [
                  {'id': d.days.single.id, 'scheduledAt': start.toIso8601String(), 'durationMin': 60},
                  {'scheduledAt': start.add(const Duration(days: 1)).toIso8601String(), 'durationMin': 90},
                ],
              }),
              id: id,
            ),
            isNull,
          );
          d = await c.detail(row);
          expect(d.days, hasLength(2));
          expect(d.days.last.durationMin, 90);
          expect(d.days.map((x) => x.seq), [1, 2]);
          expect(
            await c.saveSession(
              editBody(d, {
                'occurrences': [
                  {'id': d.days.first.id, 'scheduledAt': start.toIso8601String(), 'durationMin': 60},
                ],
              }),
              id: id,
            ),
            isNull,
          );
          expect((await c.detail(row)).days, hasLength(1));

          // Publish: it opens for registration, and cannot be published twice.
          expect(await c.publishSession(row), isNull);
          d = await c.detail(row);
          expect(d.scheduled, isTrue);
          expect(await c.publishSession(row), 'This session is already published.');
          // Attendance can only be recorded once a day has started.
          expect(
            await c.completeSession(d, const [], durationMin: 60),
            'This session hasn’t started yet — you can record attendance once it begins.',
          );

          // Cancel needs a reason of 3 to 500 characters, and closes the session.
          expect(await c.cancelSession(d, 'ab'), isNotNull);
          expect(await c.cancelSession(d, 'A live test: taking the fixture session down.'), isNull);
          d = await c.detail(row);
          expect(d.cancelled, isTrue);
          expect(d.cancelReason, 'A live test: taking the fixture session down.');
          expect(d.openDays, isEmpty);
          expect(
            await c.cancelSession(d, 'Again, for good measure'),
            isNull,
            reason: 'the API accepts a repeat cancel of a cancelled session',
          );
          expect(
            await c.saveSession(editBody(d, {'title': 'Edited after cancel'}), id: id),
            isNull,
            reason: 'the API only refuses a session that has run',
          );
        } finally {
          // A session has no delete in the API: make sure every one this test made ends cancelled.
          try {
            await c.sessions.load();
            for (final s in c.sessions.data ?? const <HostedSession>[]) {
              if (s.title.startsWith('Live test clinic') && !s.closed) {
                await repo.cancelSession(s.id, 'A live test: cleaning up.');
              }
            }
          } on Object {
            // best effort
          }
        }
      },
    );

    liveTest('a session that is not the mentor\'s is refused with the API\'s sentence', () async {
      final repo = await repoFor(divya);
      await expectLater(
        repo.publishSession('dsgn-mentoring-group-draft'),
        throwsA(predicate((e) => e.toString() == 'Only the host can do that.')),
      );
      await expectLater(
        repo.cancelSession('dsgn-mentoring-group-clinic', 'Not mine to cancel'),
        throwsA(predicate((e) => e.toString() == 'Only the host can do that.')),
      );
      // A mentor who is not approved to host is told so when they try.
      final other = await repoFor(const LivePerson('mentoring.kiran@design.icr.test', _password, 'Kiran Shah'));
      await expectLater(
        other.createSession({
          'title': 'Kiran\'s clinic',
          'mode': 'VIDEO',
          'meetingLink': 'https://meet.google.com/abc-defg-hij',
          'occurrences': [
            {'scheduledAt': farAhead().toIso8601String(), 'durationMin': 60},
          ],
        }),
        throwsA(
          predicate(
            (e) =>
                e.toString() ==
                'Group sessions are hosted by approved ICR mentors. Get your mentor profile listed first.',
          ),
        ),
      );
    });
  });
}
