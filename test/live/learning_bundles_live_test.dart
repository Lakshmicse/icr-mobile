/// Bundles in ICR credits and in money, against the LOCAL portal API (the build with `bundleCreditCost`, the
/// `mock-bundles` routes and `unlockedCourseIds`): the app's repository on the API's real answers, so the parsers,
/// the paths and the owner's rule (27 Oct 2026: a bundle's credits are the levels' or sets' summed, less the bundle
/// discount, never below the dearest one) are read from what the API sends, not from a fixture.
/// Run with the API up: `flutter test test/live/learning_bundles_live_test.dart`.
///
/// The reads are Bharat Buyer's (100 credits: they take nothing). The one test that redeems runs as the study
/// persona (10 credits, nothing opened: `tool/seed/learning-study.ts`) and UNDOES itself: opening a paper with credits
/// has no route back, but a credit balance is only what the unlock rows add up to, so the test deletes the rows it made
/// (through the portal's own Prisma client, `ICR_BACKEND_DIR`, default `E:/ICR/irc-portal/backend`) and checks that
/// the balance and the unlock list are as they were. If that cleanup cannot run, the test FAILS and prints the rows.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/learning_assess/api_assess_repository.dart';
import 'package:icr_mobile/features/learning_assess/assess_models.dart';

import 'live.dart';

/// The persona whose credits the redemption spends, and gives back.
const _study = LivePerson('study.cards@learning-study.icr.test', 'Study@12345', 'Study Cards');

Future<ApiAssessRepository> _repoFor(LivePerson who) async => ApiAssessRepository(api: await liveClient(who));

/// Deletes the credit unlocks a test made, so the person's credits and open papers are what they were.
Future<int> _undo(String email, List<String> paperIds) async {
  final dir = Platform.environment['ICR_BACKEND_DIR'] ?? 'E:/ICR/irc-portal/backend';
  final script =
      "const {PrismaClient}=require('@prisma/client');const p=new PrismaClient();"
      'p.learningPaperUnlock.deleteMany({where:{user:{email:${_js(email)}},source:"CREDIT",paperId:{in:[${paperIds.map(_js).join(',')}]}}})'
      '.then(r=>console.log("deleted "+r.count)).finally(()=>p.\$disconnect())';
  final result = await Process.run('node', ['-e', script], workingDirectory: dir);
  final out = '${result.stdout}'.trim();
  final match = RegExp(r'deleted (\d+)').firstMatch(out);
  if (result.exitCode != 0 || match == null) {
    fail(
      'The credits this test spent could not be given back (${result.stderr}). Delete these LearningPaperUnlock rows '
      'of $email by hand: $paperIds',
    );
  }
  return int.parse(match.group(1)!);
}

String _js(String s) => '"${s.replaceAll('"', r'\"')}"';

void main() {
  liveTest('a mock exam\'s bundle: credits summed, less the discount, never below the dearest; each set at its own', () async {
    final repo = await _repoFor(bharat);
    final subjects = await repo.groups(PaperKind.mock);
    expect(subjects, isNotEmpty);

    var offered = 0;
    for (final subject in subjects) {
      final q = await repo.bundleQuote(subject.key, kind: PaperKind.mock);
      expect(q.mock, isTrue);
      expect(q.courseCode, subject.key);
      if (!q.creditsOffered) {
        // Not on offer: fewer than two closed, or no saving; the app draws nothing for it.
        expect(q.inCredits == null || q.hasOffer, isTrue);
        continue;
      }
      offered++;
      final each = [for (final l in q.creditLevels) l.credits!];
      expect(each.length, greaterThanOrEqualTo(2), reason: '${subject.key}: a bundle is two or more');
      expect(q.separateCredits, each.reduce((a, b) => a + b), reason: '${subject.key}: separately is the sum');
      expect(q.credits, greaterThanOrEqualTo(each.reduce((a, b) => a > b ? a : b)), reason: 'never below the dearest');
      expect(q.creditsSaved, q.separateCredits! - q.credits!);
      expect(q.creditsSaved, greaterThan(0), reason: 'offered only while it saves something');
      expect(q.inCredits, q.credits);
      expect(q.count, q.offered ? q.levels.length : each.length);
    }
    expect(offered, greaterThan(0), reason: 'the seeded mock exams have two sets each: some bundle is on offer');
  });

  liveTest('AEE CEM: Set 1 is priced (₹299) and Set 2 is not; the money shows for one, the credits for both', () async {
    final repo = await _repoFor(bharat);
    final cem = await repo.group(PaperKind.mock, 'aee-cem');
    final set1 = cem.sets.first;
    final set2 = cem.sets.last;
    expect(set1.priced, isTrue, reason: 'staff set a price on Set 1');
    expect(set2.priced, isFalse, reason: 'Set 2 has none: credits only');

    final q1 = await repo.quote(set1);
    expect(q1.priced, isTrue);
    expect(q1.listPaisa, 29900);
    expect(q1.salePaisa, q1.listPaisa - q1.discountPaisa);
    expect(q1.taxPaisa, greaterThan(0));
    expect(q1.credits, isNotNull, reason: 'a priced set is also open with credits');
    final q2 = await repo.quote(set2);
    expect(q2.priced, isFalse);
    expect(q2.credits, isNotNull);

    final bundle = await repo.bundleQuote('aee-cem', kind: PaperKind.mock);
    expect(bundle.offered, isFalse, reason: 'one priced set is not a money bundle');
    expect(bundle.separateCredits, q1.credits! + q2.credits!);
    expect(bundle.creditLevels.map((l) => l.title), ['Set 1', 'Set 2']);
  });

  liveTest('every programme\'s bundle quote parses, and a credit bundle names the levels it would open', () async {
    final repo = await _repoFor(bharat);
    final programmes = await repo.groups(PaperKind.assessment);
    expect(programmes, isNotEmpty);
    for (final p in programmes) {
      final q = await repo.bundleQuote(p.key);
      expect(q.mock, isFalse);
      expect(q.courseCode.toLowerCase(), p.key.toLowerCase());
      if (q.creditsOffered) {
        expect(q.creditLevels.length, greaterThanOrEqualTo(2));
        expect([for (final l in q.creditLevels) l.credits!].reduce((a, b) => a + b), q.separateCredits);
      }
      if (q.offered) {
        expect(q.salePaisa, lessThan(q.separateSalePaisa));
        expect(q.savePaisa, q.separateSalePaisa - q.salePaisa);
      }
    }
  });

  liveTest('the member\'s unlocks carry the courses a level was opened under', () async {
    final repo = await _repoFor(bharat);
    final m = await repo.member(PaperKind.assessment);
    expect(m.access, isNotNull);
    // Bharat opened two levels with credits: their courses are named (a flash-card deck of the same name follows).
    expect(m.access!.creditPaperIds, isNotEmpty);
    expect(m.access!.unlockedCourseIds, isNotEmpty);
  });

  liveTest('redeeming a mock exam\'s bundle opens every set, takes the quoted credits, refuses a second go — and is undone', () async {
    final repo = await _repoFor(_study);
    final before = (await repo.member(PaperKind.mock)).access!;
    expect(before.paperIds, isEmpty, reason: 'the study persona holds no paper: run tool/seed/learning-study.ts');
    final held = before.icrCredits;

    BundleQuote? picked;
    for (final subject in await repo.groups(PaperKind.mock)) {
      final q = await repo.bundleQuote(subject.key, kind: PaperKind.mock);
      if (q.inCredits != null && q.inCredits! <= held) {
        picked = q;
        break;
      }
    }
    if (picked == null) {
      markTestSkipped('No mock bundle the study persona can afford with $held credits.');
      return;
    }
    final ids = [for (final l in picked.creditLevels) l.paperId];
    try {
      final r = await repo.redeemBundle(PaperKind.mock, picked.courseCode);
      expect(r.spent, picked.credits, reason: 'the quote is what it takes');
      expect(r.credits, held - picked.credits!);
      expect(r.paperIds.toSet(), ids.toSet());

      final after = (await repo.member(PaperKind.mock)).access!;
      expect(after.paperIds, containsAll(ids));
      expect(after.creditPaperIds, containsAll(ids));
      expect(after.icrCredits, held - picked.credits!);

      // Nothing is left to bundle, and a second go is refused in the API's own words.
      final again = await repo.bundleQuote(picked.courseCode, kind: PaperKind.mock);
      expect(again.hasOffer, isFalse);
      await expectLater(
        repo.redeemBundle(PaperKind.mock, picked.courseCode),
        throwsA(isA<ApiError>().having((e) => e.message, 'message', isNotEmpty)),
      );
    } finally {
      final removed = await _undo(_study.email, ids);
      expect(removed, ids.length, reason: 'every unlock the redemption made is deleted');
    }
    final restored = (await repo.member(PaperKind.mock)).access!;
    expect(restored.paperIds, isEmpty);
    expect(restored.icrCredits, held, reason: 'the credits are given back with the rows');
  });

  liveTest('a bundle the member cannot afford is refused with the API\'s sentence, and nothing changes', () async {
    final repo = await _repoFor(_study);
    final held = (await repo.member(PaperKind.mock)).access!.icrCredits;
    BundleQuote? dear;
    for (final subject in await repo.groups(PaperKind.mock)) {
      final q = await repo.bundleQuote(subject.key, kind: PaperKind.mock);
      if (q.inCredits != null && q.inCredits! > held) {
        dear = q;
        break;
      }
    }
    if (dear == null) {
      markTestSkipped('Every bundle costs $held credits or less for the study persona.');
      return;
    }
    await expectLater(
      repo.redeemBundle(PaperKind.mock, dear.courseCode),
      throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 403)),
    );
    expect((await repo.member(PaperKind.mock)).access!.icrCredits, held);
  });
}
