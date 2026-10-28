/// The career screens' company insights against the LOCAL portal API: each control
/// does the real thing, the effect is read back through the API, and what can be
/// undone is undone.
///
/// What cannot be undone through the API, and what the test does about it:
///  - A company review can only be replaced, never deleted: Pooja's review of the
///    Insights Sandbox company stays (PENDING, so it is not public); the next run
///    replaces it.
///  - A salary report or an interview experience is a new row each time. The tests
///    write them to the sandbox company, which nothing reads, and mark theirs with
///    the job title "MOBILE-LIVE tester"; `tool/seed/career.ts` sweeps them at every
///    run (and `--remove`).
///
/// Needs the seeds of `tool/seed` (`learning-jobs.ts`, then `career.ts`).
@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/career/api_career_repository.dart';
import 'package:icr_mobile/features/career/career_models.dart';
import 'package:icr_mobile/features/career/company_insights_controller.dart';
import 'package:icr_mobile/features/jobs/api_jobs_repository.dart';

import 'live.dart';

/// The seeded company the insights tests READ (`learning-jobs.ts` made it, `career.ts` gave it reviews).
const company = 'design-lj-co-global-infra';

/// The empty company the insights tests WRITE to (`career.ts`).
const sandbox = 'design-career-co-sandbox';

/// What the tests title their salary reports and interview experiences, so the seed can sweep them away.
const marker = 'MOBILE-LIVE tester';

Future<ApiCareerRepository> careerFor(LivePerson who, {int? pageSize}) async {
  final api = await liveClient(who);
  return ApiCareerRepository(
    api: api,
    jobs: ApiJobsRepository(api: api),
    pageSize: pageSize ?? ApiCareerRepository.insightsPageSize,
  );
}

void main() {
  group('a company\'s insights', () {
    liveTest('the five tabs read what the API holds, in the shapes the screens draw', () async {
      final repo = await careerFor(bharat);

      final summary = await repo.ratingSummary(company);
      expect(summary.distribution.keys, containsAll([1, 2, 3, 4, 5]));
      expect(summary.count, greaterThanOrEqualTo(4), reason: 'career.ts seeds four approved reviews');
      expect(summary.average, inInclusiveRange(1, 5));
      expect(summary.subRatings.keys, contains('Work-life balance'));

      final reviews = await repo.reviews(company);
      expect(reviews.items.length, lessThanOrEqualTo(ApiCareerRepository.insightsPageSize));
      expect(reviews.items, isNotEmpty);
      for (final r in reviews.items) {
        expect(r.rating, inInclusiveRange(1, 5));
        expect(r.status, isNull, reason: 'a public review carries no moderation status');
        expect(r.title, isNotEmpty);
      }
      expect(
        reviews.items.any((r) => r.verifiedEmployee),
        isTrue,
        reason: 'one seeded review is by a verified employee',
      );

      final salaries = await repo.salaries(company);
      expect(salaries.minSample, 5);
      expect(salaries.insufficient, isFalse);
      final fm = salaries.roles.firstWhere((r) => r.jobTitle == 'Facilities Manager');
      expect(fm.count, greaterThanOrEqualTo(5));
      expect(fm.p25, lessThanOrEqualTo(fm.median));
      expect(fm.median, lessThanOrEqualTo(fm.p75));
      expect(salaries.roles.every((r) => r.count >= salaries.minSample), isTrue);

      final interviews = await repo.interviewReviews(company);
      expect(interviews.items, isNotEmpty);
      expect(interviews.averages.keys, containsAll(['difficulty', 'experience']));
      final first = interviews.items.first;
      expect(first.difficultyLabel, isNotNull);
      expect(first.outcomeLabel, isNotNull);

      final people = await repo.people(company);
      expect(people.items, isNotEmpty, reason: 'learning-jobs.ts puts people at Global Infra');
      expect(people.total, greaterThanOrEqualTo(people.items.length));
      expect(people.items.first.name, isNotEmpty);
      for (final p in people.items.where((p) => p.photo != null)) {
        expect(p.photo!.url, startsWith('http'), reason: 'an upload path is made absolute');
      }

      final jobs = await repo.companyJobs(company);
      expect(jobs.jobs, isNotEmpty);
      expect(jobs.jobs.every((j) => j.company.id == company), isTrue);
    });

    liveTest('paging: the second page of people follows the first, with no one twice', () async {
      final repo = await careerFor(bharat, pageSize: 2);
      final first = await repo.people(company);
      expect(first.items.length, 2);
      expect(first.hasMore, isTrue, reason: 'Global Infra has five public members');
      final second = await repo.people(company, page: 2);
      final ids = {...first.items.map((p) => p.id)};
      expect(second.items, isNotEmpty);
      expect(second.items.every((p) => ids.add(p.id)), isTrue);
    });

    liveTest('paging: reviews and interview experiences page the same way', () async {
      final repo = await careerFor(bharat, pageSize: 2);
      final first = await repo.reviews(company);
      expect(first.items.length, 2);
      expect(first.hasMore, isTrue);
      final second = await repo.reviews(company, page: 2);
      final seen = {...first.items.map((r) => r.id), ...second.items.map((r) => r.id)};
      expect(seen.length, first.items.length + second.items.length, reason: 'no review twice');

      final iv1 = await repo.interviewReviews(company);
      expect(iv1.items.length, 2);
      final iv2 = await repo.interviewReviews(company, page: 2);
      expect(iv2.items.map((r) => r.id).toSet().intersection(iv1.items.map((r) => r.id).toSet()), isEmpty);
    });

    liveTest(
      'a review is sent, waits for moderation, is read back as the author\'s own, and a second replaces it',
      () async {
        final repo = await careerFor(pooja);
        final publicBefore = (await repo.reviews(sandbox)).total;

        await repo.submitReview(
          sandbox,
          const ReviewDraft(
            overall: 4,
            title: 'MOBILE-LIVE review',
            pros: 'Written by the mobile live test.',
            cons: 'Replaced on every run.',
            subRatings: {'workLife': 5, 'growth': 3},
            employmentStatus: 'CURRENT',
          ),
        );
        var mine = await repo.myReview(sandbox);
        expect(mine, isNotNull);
        expect((mine!.status, mine.rating, mine.title), ('PENDING', 4, 'MOBILE-LIVE review'));
        expect(mine.subRatings, {'workLife': 5, 'growth': 3});
        expect(mine.employmentStatus, 'CURRENT');
        expect((await repo.reviews(sandbox)).total, publicBefore, reason: 'a pending review is not public');

        await repo.submitReview(
          sandbox,
          const ReviewDraft(overall: 2, title: 'MOBILE-LIVE review', pros: 'Again.', cons: 'Again.'),
        );
        mine = await repo.myReview(sandbox);
        expect((mine!.rating, mine.pros), (2, 'Again.'), reason: 'the second one replaced the first');
        // The API keeps a sub-rating the new review does not send (its upsert leaves undefined fields alone),
        // which is why the form opens with the earlier stars and sends them all again.
        expect(mine.subRatings, {'workLife': 5, 'growth': 3});
      },
    );

    liveTest('someone who never reviewed has no review of their own: the API answers with nothing', () async {
      final repo = await careerFor(bharat);
      expect(await repo.myReview('design-lj-co-cbre-green'), isNull);
    });

    liveTest(
      'a salary report and an interview experience are accepted (anonymous, so they only ever show as aggregates)',
      () async {
        final repo = await careerFor(pooja);
        await repo.submitSalary(
          sandbox,
          const SalaryDraft(
            jobTitle: marker,
            amount: 85000,
            period: 'MONTHLY',
            city: 'Bengaluru',
            years: 6,
            employmentStatus: 'CURRENT',
          ),
        );
        await repo.submitInterviewReview(
          sandbox,
          const InterviewReviewDraft(
            difficulty: 3,
            experience: 4,
            process: 'Sent by the mobile live test.',
            jobTitle: marker,
            outcome: 'IN_PROGRESS',
            questions: 'None.',
            durationDays: 7,
          ),
        );
        final salaries = await repo.salaries(sandbox);
        expect(
          salaries.roles.every((r) => r.count >= salaries.minSample),
          isTrue,
          reason: 'a role shows only once enough people reported it',
        );
        expect(salaries.totalReports, greaterThan(0));
        // The interview experience is pending: moderation has not read it, so it is not on the public list.
        expect((await repo.interviewReviews(sandbox)).items.where((r) => r.jobTitle == marker), isEmpty);
      },
    );

    liveTest('the API\'s own refusal is the sentence the form shows: a company that is not there', () async {
      final repo = await careerFor(pooja);
      final c = CompanyInsightsController(
        repository: repo,
        company: const JobCompany(id: 'no-such-company', name: 'Nowhere'),
      );
      addTearDown(c.dispose);
      final message = await c.submitReview(const ReviewDraft(overall: 3, title: 't', pros: 'p', cons: 'c'));
      expect(message, 'Company not found');
      expect(
        () => repo.submitSalary('no-such-company', const SalaryDraft(jobTitle: marker, amount: 1)),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 404)),
      );
    });

    liveTest('a form the DTO would refuse never leaves the phone: the controller answers with the sentence', () async {
      final repo = await careerFor(pooja);
      final c = CompanyInsightsController(
        repository: repo,
        company: const JobCompany(id: sandbox, name: 'Sandbox'),
      );
      addTearDown(c.dispose);
      expect(
        await c.submitReview(const ReviewDraft(overall: 3, title: ' ', pros: 'p', cons: 'c')),
        contains('required'),
      );
      expect(await c.submitReview(ReviewDraft(overall: 3, title: 'x' * 141, pros: 'p', cons: 'c')), contains('140'));
    });

    liveTest('the controller reads each tab on first show and the member\'s own review with the summary', () async {
      final repo = await careerFor(pooja);
      final c = CompanyInsightsController(
        repository: repo,
        company: const JobCompany(id: company, name: 'Global Infra Solutions'),
        tab: InsightsTab.reviews,
      );
      addTearDown(c.dispose);
      await c.start();
      expect(c.summary, isNotNull);
      expect(c.reviews.loaded, isTrue);
      expect(c.reviews.items, isNotEmpty);
      expect(c.people.loaded, isFalse);
      await c.select(InsightsTab.people);
      expect(c.people.items, isNotEmpty);
      await c.select(InsightsTab.jobs);
      expect(c.jobs.items, isNotEmpty);
      await c.select(InsightsTab.salaries);
      expect(c.salaryState.loaded, isTrue);
      expect(c.salaryState.items, isNotEmpty);
      await c.select(InsightsTab.interviews);
      expect(c.interviews.items, isNotEmpty);
      expect(c.mine?.status, anyOf('PENDING', 'APPROVED', 'REJECTED', isNull));
    });
  });
}
