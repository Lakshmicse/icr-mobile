import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/career/career_models.dart';
import 'package:icr_mobile/features/career/company_insights_controller.dart';
import 'package:icr_mobile/features/career/company_insights_screen.dart';
import 'package:icr_mobile/features/career/demo_career_repository.dart';
import 'package:icr_mobile/features/jobs/jobs_navigation.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'career_fakes.dart';
import 'helpers/fonts.dart';
import 'jobs_fakes.dart';

const _company = JobCompany(id: 'c1', name: 'Global Infra Solutions', city: 'Bengaluru', size: '500+ employees');

/// The demo career source with answers a test can replace.
class ScriptedCareer extends DemoCareerRepository {
  bool failReviews = false;
  bool empty = false;
  ApiError? submitError;
  final reviewPages = <int>[];

  @override
  Future<InsightPage<EmployerReview>> reviews(String companyId, {int page = 1}) async {
    reviewPages.add(page);
    if (failReviews) throw ApiError('Reviews are down.', statusCode: 500);
    if (empty) return const InsightPage(items: [], hasMore: false, total: 0);
    return super.reviews(companyId, page: page);
  }

  @override
  Future<RatingSummary> ratingSummary(String companyId) async =>
      empty ? const RatingSummary() : super.ratingSummary(companyId);

  @override
  Future<SalaryInsights> salaries(String companyId) async =>
      empty ? const SalaryInsights(totalReports: 3) : super.salaries(companyId);

  @override
  Future<InsightPage<InterviewReview>> interviewReviews(String companyId, {int page = 1}) async =>
      empty ? const InsightPage(items: [], hasMore: false) : super.interviewReviews(companyId, page: page);

  @override
  Future<InsightPage<CompanyPerson>> people(String companyId, {int page = 1}) async =>
      empty ? const InsightPage(items: [], hasMore: false, total: 0) : super.people(companyId, page: page);

  @override
  Future<JobPage> companyJobs(String companyId, {int page = 1}) async =>
      empty ? const JobPage(jobs: [], hasMore: false) : super.companyJobs(companyId, page: page);

  @override
  Future<void> submitReview(String companyId, ReviewDraft draft) async {
    final error = submitError;
    if (error != null) throw error;
    await super.submitReview(companyId, draft);
  }
}

Future<RecordingLinks> pumpInsights(
  WidgetTester tester,
  ScriptedCareer repo, {
  InsightsTab tab = InsightsTab.reviews,
  JobsNavigation navigation = JobsNavigation.none,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final links = RecordingLinks();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: CompanyInsightsScreen(repository: repo, company: _company, links: links, navigation: navigation, tab: tab),
    ),
  );
  await tester.pumpAndSettle();
  return links;
}

Future<void> openTab(WidgetTester tester, InsightsTab tab) async {
  await tester.tap(find.byKey(ValueKey('tab-${tab.name}')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('the API mapping', () {
    const review = {
      'id': 'r1',
      'overallRating': 4,
      'ratingWorkLife': 5,
      'ratingGrowth': 3,
      'title': 'Good',
      'pros': 'Pros',
      'cons': 'Cons',
      'advice': null,
      'jobTitle': 'Engineer',
      'employmentStatus': 'CURRENT',
      'isVerifiedEmployee': true,
      'createdAt': '2026-09-14T08:00:00.000Z',
    };

    test('a page of reviews, with its paging, and the author\'s own review (empty body when none)', () async {
      final api = FakeApi({
        'GET /companies/c1/reviews': (_) => {
          'data': [review],
          'meta': {'total': 12, 'hasNext': true},
        },
        'GET /companies/c1/reviews/mine': (_) => null,
        'GET /companies/c2/reviews/mine': (_) => {...review, 'id': 'mine', 'status': 'PENDING'},
      });
      final repo = apiCareer(api);
      final page = await repo.reviews('c1', page: 2);
      expect(api.last('GET /companies/c1/reviews').queryParameters, {'page': 2, 'limit': 10});
      expect(page.hasMore, isTrue);
      expect(page.total, 12);
      final r = page.items.single;
      expect(
        (r.rating, r.title, r.jobTitle, r.employmentStatus, r.verifiedEmployee),
        (4, 'Good', 'Engineer', 'CURRENT', true),
      );
      expect(r.subRatings, {'workLife': 5, 'growth': 3});
      expect(r.status, isNull);

      expect(await repo.myReview('c1'), isNull);
      expect((await repo.myReview('c2'))!.status, 'PENDING');
    });

    test('the rating summary reads the five averages by the website\'s names', () async {
      final repo = apiCareer(
        FakeApi({
          'GET /companies/c1/rating-summary': (_) => {
            'count': 3,
            'average': 4.3,
            'distribution': {'1': 0, '2': 0, '3': 1, '4': 1, '5': 1},
            'subRatings': {'workLife': 4.5, 'compensation': null, 'culture': 3.0, 'management': null, 'growth': null},
          },
        }),
      );
      final s = await repo.ratingSummary('c1');
      expect((s.count, s.average), (3, 4.3));
      expect(s.distribution[5], 1);
      expect(s.subRatings, {'Work-life balance': 4.5, 'Culture': 3.0});
    });

    test('salaries: roles with their percentiles, or none when the sample is too small', () async {
      final repo = apiCareer(
        FakeApi({
          'GET /companies/c1/salaries': (_) => {
            'minSample': 5,
            'totalReports': 9,
            'insufficient': false,
            'roles': [
              {
                'jobTitle': 'Manager',
                'count': 6,
                'p25': 1200000.0,
                'median': 1500000.0,
                'p75': 1900000.5,
                'avgExperience': null,
              },
            ],
          },
          'GET /companies/c2/salaries': (_) => {'minSample': 5, 'totalReports': 2, 'insufficient': true, 'roles': []},
        }),
      );
      final s = await repo.salaries('c1');
      expect(s.roles.single.jobTitle, 'Manager');
      expect(s.roles.single.p75, 1900000.5);
      expect(s.roles.single.avgExperience, isNull);
      expect(s.insufficient, isFalse);
      final none = await repo.salaries('c2');
      expect((none.insufficient, none.totalReports), (true, 2));
    });

    test('interview experiences carry the API\'s averages; people carry a photo path and a headline', () async {
      final repo = apiCareer(
        FakeApi({
          'GET /companies/c1/interview-reviews': (_) => {
            'data': [
              {
                'id': 'i1',
                'jobTitle': 'Manager',
                'difficulty': 4,
                'experienceRating': 2,
                'outcome': 'NO_OFFER',
                'processDescription': 'Two rounds',
                'questionsAsked': null,
                'durationDays': 14,
                'createdAt': '2026-09-01T00:00:00.000Z',
              },
            ],
            'meta': {'total': 1, 'hasNext': false},
            'averages': {'difficulty': 4.0, 'experience': 2.5},
          },
          'GET /companies/c1/people': (_) => {
            'data': [
              {
                'id': 'u1',
                'firstName': 'Priya',
                'lastName': 'Sharma',
                'avatarUrl': '/uploads/p.png',
                'headline': 'Talent',
              },
              {'id': 'u2', 'firstName': 'Omkar', 'lastName': 'Patil', 'avatarUrl': null, 'headline': null},
            ],
            'meta': {'total': 5, 'hasNext': true},
          },
        }),
      );
      final iv = await repo.interviewReviews('c1');
      expect(iv.averages, {'difficulty': 4.0, 'experience': 2.5});
      final item = iv.items.single;
      expect(
        (item.difficultyLabel, item.experienceLabel, item.outcomeLabel),
        ('Hard', 'Negative experience', 'No offer'),
      );
      final people = await repo.people('c1');
      expect(people.total, 5);
      expect(people.hasMore, isTrue);
      expect(people.items.first.name, 'Priya Sharma');
      expect(people.items.first.photo!.url, 'http://api.test/uploads/p.png');
      expect(people.items.last.initials, 'OP');
    });

    test('the three forms send what the DTOs name, blanks left out', () async {
      final api = FakeApi({
        'POST /companies/c1/reviews': (_) => {'id': 'x'},
        'POST /companies/c1/salaries': (_) => {'id': 'x'},
        'POST /companies/c1/interview-reviews': (_) => {'id': 'x'},
      });
      final repo = apiCareer(api);
      await repo.submitReview(
        'c1',
        const ReviewDraft(
          overall: 4,
          title: ' Good ',
          pros: 'P',
          cons: 'C',
          subRatings: {'workLife': 5, 'growth': 2},
          advice: '  ',
          employmentStatus: 'FORMER',
        ),
      );
      expect(api.last('POST /companies/c1/reviews').data, {
        'overallRating': 4,
        'ratingWorkLife': 5,
        'ratingGrowth': 2,
        'title': 'Good',
        'pros': 'P',
        'cons': 'C',
        'employmentStatus': 'FORMER',
      });
      await repo.submitSalary(
        'c1',
        const SalaryDraft(jobTitle: 'Manager', amount: 900000, period: 'MONTHLY', years: 6),
      );
      expect(api.last('POST /companies/c1/salaries').data, {
        'jobTitle': 'Manager',
        'salaryAmount': 900000,
        'salaryPeriod': 'MONTHLY',
        'yearsExperience': 6,
      });
      await repo.submitInterviewReview(
        'c1',
        const InterviewReviewDraft(
          difficulty: 3,
          experience: 4,
          process: ' Fine ',
          outcome: 'NO_OFFER',
          durationDays: 10,
        ),
      );
      expect(api.last('POST /companies/c1/interview-reviews').data, {
        'difficulty': 3,
        'experienceRating': 4,
        'outcome': 'NO_OFFER',
        'processDescription': 'Fine',
        'durationDays': 10,
      });
    });
  });

  group('the forms refuse what the DTOs would', () {
    test('a review needs a rating, a headline, pros and cons, within the limits', () {
      const ok = ReviewDraft(overall: 3, title: 't', pros: 'p', cons: 'c');
      expect(ok.problem, isNull);
      expect(const ReviewDraft(overall: 0, title: 't', pros: 'p', cons: 'c').problem, contains('required'));
      expect(const ReviewDraft(overall: 3, title: ' ', pros: 'p', cons: 'c').problem, contains('required'));
      expect(ReviewDraft(overall: 3, title: 'x' * 141, pros: 'p', cons: 'c').problem, contains('140'));
      expect(ReviewDraft(overall: 3, title: 't', pros: 'x' * 4001, cons: 'c').problem, contains('4000'));
    });

    test('a salary needs a title and an amount of 0 or more', () {
      expect(const SalaryDraft(jobTitle: 'M', amount: 1).problem, isNull);
      expect(const SalaryDraft(jobTitle: '', amount: 1).problem, contains('required'));
      expect(const SalaryDraft(jobTitle: 'M', amount: null).problem, contains('required'));
      expect(const SalaryDraft(jobTitle: 'M', amount: -1).problem, contains('0 or more'));
    });

    test('an interview needs difficulty, experience and the process', () {
      expect(const InterviewReviewDraft(difficulty: 3, experience: 3, process: 'p').problem, isNull);
      expect(const InterviewReviewDraft(difficulty: 0, experience: 3, process: 'p').problem, contains('required'));
      expect(const InterviewReviewDraft(difficulty: 3, experience: 3, process: ' ').problem, contains('required'));
    });
  });

  group('the controller', () {
    test('a tab reads on first show, not before, and "View More" adds the next page without repeats', () async {
      final repo = ScriptedCareer();
      final c = CompanyInsightsController(repository: repo, company: _company);
      await c.start();
      expect(c.reviews.loaded, isTrue);
      expect(c.people.loaded, isFalse, reason: 'the People tab has not been opened');
      await c.select(InsightsTab.people);
      expect(c.people.items.map((p) => p.name), ['Priya Sharma', 'Nikhil Menon']);
      c.dispose();
    });

    test('a refusal on send comes back as the sentence; a good send leaves the review PENDING', () async {
      final repo = ScriptedCareer()..submitError = ApiError('You cannot review a company you own.', statusCode: 403);
      final c = CompanyInsightsController(repository: repo, company: _company);
      await c.start();
      const draft = ReviewDraft(overall: 5, title: 'Great', pros: 'p', cons: 'c');
      expect(await c.submitReview(draft), 'You cannot review a company you own.');
      expect(c.mine, isNull);

      repo.submitError = null;
      expect(await c.submitReview(draft), isNull);
      expect(c.mine!.status, 'PENDING');
      expect(await c.submitReview(const ReviewDraft(overall: 0, title: '', pros: '', cons: '')), contains('required'));
      c.dispose();
    });

    test('a bookmark on the Jobs tab is applied at once and put back when refused', () async {
      final repo = ScriptedCareer();
      final c = CompanyInsightsController(repository: repo, company: _company, tab: InsightsTab.jobs);
      await c.start();
      final job = c.jobs.items.first;
      expect(await c.toggleSave(job), isNull);
      expect(c.jobs.items.first.saved, isTrue);
      c.dispose();
    });
  });

  group('the screen', () {
    testWidgets('a company known only by its id gets its name, city and size from the API', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: CompanyInsightsScreen.forId(repository: ScriptedCareer(), companyId: 'c9', links: RecordingLinks()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Global Infra Solutions'), findsOneWidget);
      expect(find.text('Real Estate • 500+ employees • Bengaluru'), findsOneWidget);
      // Opened by id with no tab named, it leads with the company's jobs, then people, as the website's page.
      expect(find.byKey(const ValueKey('jobs-empty')), findsNothing);
      expect(find.text('Senior Facilities Manager for STP Plant'), findsWidgets);
    });

    testWidgets('the tabs run Jobs, People, Reviews, Salaries, Interviews, as the website page does', (tester) async {
      await pumpInsights(tester, ScriptedCareer());
      final labels = [for (final tab in InsightsTab.values) tab.label];
      expect(labels, ['Jobs', 'People', 'Reviews', 'Salaries', 'Interviews']);
      final xs = [for (final tab in InsightsTab.values) tester.getTopLeft(find.byKey(ValueKey('tab-${tab.name}'))).dx];
      expect(xs, [...xs]..sort());
    });

    testWidgets('the bell opens the notifications the app wired', (tester) async {
      var bells = 0;
      await pumpInsights(tester, ScriptedCareer(), navigation: JobsNavigation(onBell: () => bells++));
      await tester.tap(find.byIcon(LucideIcons.bell));
      expect(bells, 1);
    });

    testWidgets('the bell with nothing wired opens /notifications on the website', (tester) async {
      final links = await pumpInsights(tester, ScriptedCareer());
      await tester.tap(find.byIcon(LucideIcons.bell));
      await tester.pump();
      expect(links.paths, ['/notifications']);
    });

    testWidgets('the header names the company with its rating, and Reviews lead the tabs', (tester) async {
      await pumpInsights(tester, ScriptedCareer());
      expect(find.text('Global Infra Solutions'), findsOneWidget);
      expect(find.byKey(const ValueKey('header-rating')), findsOneWidget);
      expect(find.text('4.5'), findsWidgets);
      expect(find.text('A place that lets facilities people lead'), findsOneWidget);
      expect(find.text('Verified employee'), findsOneWidget);
      expect(find.text('PROS'), findsWidgets);
      expect(find.byKey(const ValueKey('rating-card')), findsOneWidget);
    });

    testWidgets('Salaries lists each role with its typical pay and range', (tester) async {
      await pumpInsights(tester, ScriptedCareer());
      await openTab(tester, InsightsTab.salaries);
      expect(find.text('Facilities Manager'), findsOneWidget);
      expect(find.text('₹18L'), findsOneWidget);
      expect(find.textContaining('₹14L to ₹23L'), findsOneWidget);
    });

    testWidgets('Interviews shows the averages and each experience\'s facts', (tester) async {
      await pumpInsights(tester, ScriptedCareer());
      await openTab(tester, InsightsTab.interviews);
      expect(find.byKey(const ValueKey('interview-averages')), findsOneWidget);
      expect(find.text('3.0 / 5'), findsOneWidget);
      expect(find.text('Offer accepted'), findsNothing, reason: 'the outcome reads as the website words it');
      expect(find.text('Got an offer and accepted'), findsOneWidget);
      expect(find.text('Average difficulty'), findsOneWidget);
    });

    testWidgets('People: a row opens that person\'s profile through the callback', (tester) async {
      final opened = <String>[];
      await pumpInsights(tester, ScriptedCareer(), navigation: JobsNavigation(onOpenProfile: opened.add));
      await openTab(tester, InsightsTab.people);
      expect(find.text('2 people from Global Infra Solutions on ICR'), findsOneWidget);
      await tester.tap(find.text('Nikhil Menon'));
      expect(opened, ['nikhil']);
    });

    testWidgets('People with nothing wired opens the member on the website', (tester) async {
      final links = await pumpInsights(tester, ScriptedCareer());
      await openTab(tester, InsightsTab.people);
      await tester.tap(find.text('Priya Sharma'));
      await tester.pump();
      expect(links.paths, ['/members/priya']);
    });

    testWidgets('"See the company page" opens it: the app\'s page when wired, else the website\'s', (tester) async {
      final opened = <String>[];
      await pumpInsights(tester, ScriptedCareer(), navigation: JobsNavigation(onOpenCompany: opened.add));
      await tester.tap(find.byKey(const ValueKey('company-page')));
      expect(opened, ['c1']);
    });

    testWidgets('the website\'s company page opens when the app has none wired', (tester) async {
      final links = await pumpInsights(tester, ScriptedCareer());
      await tester.tap(find.byKey(const ValueKey('company-page')));
      await tester.pump();
      expect(links.paths, ['/companies/c1']);
    });

    testWidgets('Jobs: a row opens the job sheet, and its bookmark saves', (tester) async {
      await pumpInsights(tester, ScriptedCareer(), tab: InsightsTab.jobs);
      expect(find.text('Senior Facilities Manager for STP Plant'), findsWidgets);
      await tester.tap(find.byIcon(LucideIcons.bookmark).first);
      await tester.pump();
      expect(find.byIcon(LucideIcons.bookmarkCheck), findsOneWidget);
    });

    testWidgets('a tab that fails says why and Try again reads it again', (tester) async {
      final repo = ScriptedCareer()..failReviews = true;
      await pumpInsights(tester, repo);
      expect(find.byKey(const ValueKey('tab-error')), findsOneWidget);
      expect(find.text('Reviews are down.'), findsOneWidget);
      repo.failReviews = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('A place that lets facilities people lead'), findsOneWidget);
    });

    testWidgets('every tab has an empty state', (tester) async {
      await pumpInsights(tester, ScriptedCareer()..empty = true);
      expect(find.byKey(const ValueKey('reviews-empty')), findsOneWidget);
      await openTab(tester, InsightsTab.salaries);
      expect(find.byKey(const ValueKey('salaries-empty')), findsOneWidget);
      expect(find.textContaining('5 people have reported it'), findsOneWidget);
      expect(find.textContaining('3 so far'), findsOneWidget);
      await openTab(tester, InsightsTab.interviews);
      expect(find.byKey(const ValueKey('interviews-empty')), findsOneWidget);
      await openTab(tester, InsightsTab.people);
      expect(find.byKey(const ValueKey('people-empty')), findsOneWidget);
      await openTab(tester, InsightsTab.jobs);
      expect(find.byKey(const ValueKey('jobs-empty')), findsOneWidget);
    });

    testWidgets('pull to refresh reads the open tab again', (tester) async {
      final repo = ScriptedCareer();
      await pumpInsights(tester, repo);
      expect(repo.reviewPages, [1]);
      await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(repo.reviewPages.length, greaterThan(1));
    });
  });

  group('writing a review', () {
    Future<void> fill(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('overall-4')));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('review-title')), 'Worth it');
      await tester.enterText(find.byKey(const ValueKey('review-pros')), 'Good people');
      await tester.enterText(find.byKey(const ValueKey('review-cons')), 'Long audits');
    }

    testWidgets('an empty form says what is required and sends nothing', (tester) async {
      final repo = ScriptedCareer();
      await pumpInsights(tester, repo);
      await tester.tap(find.byKey(const ValueKey('write-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit review'));
      await tester.pump();
      expect(find.text('Overall rating, a headline, pros and cons are required.'), findsOneWidget);
      expect(repo.calls, isNot(contains('submitReview')));
    });

    testWidgets('a good review is sent, the form closes, and the screen says it is waiting for ICR', (tester) async {
      final repo = ScriptedCareer();
      await pumpInsights(tester, repo);
      await tester.tap(find.byKey(const ValueKey('write-review')));
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('status-CURRENT')));
      await tester.tap(find.byKey(const ValueKey('status-CURRENT')));
      await tester.pump();
      await tester.tap(find.text('Submit review'));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('submitReview'));
      expect(repo.sentReview!.employmentStatus, 'CURRENT');
      expect(find.text('Submit review'), findsNothing, reason: 'the form closed');
      expect(find.textContaining('appears once ICR has read it'), findsOneWidget);
      expect(find.byKey(const ValueKey('my-review')), findsOneWidget);
      expect(find.text('Update my review'), findsOneWidget);
    });

    testWidgets('a refusal keeps what was typed and shows the API\'s sentence', (tester) async {
      final repo = ScriptedCareer()..submitError = ApiError('This company is suspended.', statusCode: 404);
      await pumpInsights(tester, repo);
      await tester.tap(find.byKey(const ValueKey('write-review')));
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.tap(find.text('Submit review'));
      await tester.pumpAndSettle();
      expect(find.text('This company is suspended.'), findsOneWidget);
      expect(find.text('Worth it'), findsOneWidget, reason: 'the headline is still there');
      repo.submitError = null;
      await tester.tap(find.text('Submit review'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('submitReview'));
    });
  });

  group('sharing a salary and an interview', () {
    testWidgets('a salary needs a title and an amount, then is sent', (tester) async {
      final repo = ScriptedCareer();
      await pumpInsights(tester, repo);
      await openTab(tester, InsightsTab.salaries);
      await tester.tap(find.byKey(const ValueKey('share-salary')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share salary'));
      await tester.pump();
      expect(find.text('A job title and an amount are required.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('salary-title')), 'Facilities Manager');
      await tester.enterText(find.byKey(const ValueKey('salary-amount')), '95000');
      await tester.tap(find.byKey(const ValueKey('period-MONTHLY')));
      await tester.pump();
      await tester.tap(find.text('Share salary'));
      await tester.pumpAndSettle();
      final sent = repo.salaryReports.single;
      expect((sent.jobTitle, sent.amount, sent.period), ('Facilities Manager', 95000, 'MONTHLY'));
      expect(find.textContaining('only ever shown as an average'), findsOneWidget);
    });

    testWidgets('an interview needs its ratings and the process, then is sent', (tester) async {
      final repo = ScriptedCareer();
      await pumpInsights(tester, repo);
      await openTab(tester, InsightsTab.interviews);
      await tester.tap(find.byKey(const ValueKey('share-interview')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share interview'));
      await tester.pump();
      expect(find.byKey(const ValueKey('form-problem')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('difficulty-4')));
      await tester.tap(find.byKey(const ValueKey('experience-5')));
      await tester.tap(find.byKey(const ValueKey('outcome-NO_OFFER')));
      await tester.enterText(find.byKey(const ValueKey('interview-process')), 'Three rounds over two weeks.');
      await tester.pump();
      await tester.tap(find.text('Share interview'));
      await tester.pumpAndSettle();
      final sent = repo.interviewReports.single;
      expect((sent.difficulty, sent.experience, sent.outcome), (4, 5, 'NO_OFFER'));
    });
  });
}
