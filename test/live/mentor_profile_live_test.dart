/// The Mentor Profile against the LOCAL API, with the seeded design mentor
/// (Srikanth Sriramagiri, profile `dsgn-mentorship-mp-srikanth`; run
/// `tool/seed/mentorship.ts` first). Each control that reads or writes through the
/// API is exercised through the screen's own repository and controller and
/// proved by reading the effect back; what it does it undoes, except where the
/// API has no way back (a free resource taken is a purchase the API keeps; the
/// test says so).
///
///     flutter test test/live/mentor_profile_live_test.dart
library;

import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/mentor_profile/api_mentor_profile_repository.dart';
import 'package:icr_mobile/features/mentor_profile/mentor_profile_controller.dart';
import 'package:icr_mobile/features/mentor_profile/mentor_profile_format.dart';
import 'package:icr_mobile/features/mentor_profile/mentor_profile_models.dart';
import 'package:icr_mobile/features/mentor_profile/widgets/profile_hero.dart';

import 'live.dart';

const srikanthId = 'dsgn-mentorship-mp-srikanth';

/// A seeded mentee of Srikanth's with a live pairing (Message opens its thread).
const yash = LivePerson('mentorship.mentee-yash@design.icr.test', 'Password123!', 'Yash Agarwal');

/// A seeded mentee with no mobile number on file: the person the phone path is proved with.
const dev = LivePerson('mentorship.mentee-dev@design.icr.test', 'Password123!', 'Dev Mangtani');

/// What the API says when an action needs a number and the profile has none.
const phoneNeeded = 'Add a mobile number so your mentor can reach you.';

final _clients = <String, ApiClient>{};

/// One sign-in per person for the whole file. The API limits sign-ins per minute, which a busy day of
/// test runs (this file's, or another suite's) can reach: that is waited out, not failed on.
Future<ApiClient> signedIn(LivePerson who) async {
  final known = _clients[who.email];
  if (known != null) return known;
  for (var attempt = 0; ; attempt++) {
    try {
      return _clients[who.email] = await liveClient(who);
    } on DioException catch (e) {
      if (e.response?.statusCode != 429 || attempt >= 6) rethrow;
      await Future<void>.delayed(const Duration(seconds: 15));
    }
  }
}

ApiMentorProfileRepository repoFor(ApiClient api) => ApiMentorProfileRepository(api: api);

Future<MentorProfileController> loaded(ApiClient api) async {
  final c = MentorProfileController(repository: repoFor(api), mentorId: srikanthId);
  await c.load();
  expect(c.error, isNull, reason: 'the profile should load: ${c.error}');
  return c;
}

Future<List<Map<String, dynamic>>> getList(ApiClient api, String path) async {
  final res = await api.dio.get<dynamic>(path);
  final data = res.data;
  final list = data is Map ? data['data'] : data;
  return (list as List).cast<Map<String, dynamic>>();
}

Future<Map<String, dynamic>> getMap(ApiClient api, String path) async =>
    (await api.dio.get<Map<String, dynamic>>(path)).data!;

Future<String?> phoneOf(ApiClient api) async {
  final me = await getMap(api, '/auth/me');
  return ((me['user'] as Map<String, dynamic>?) ?? me)['phone'] as String?;
}

void main() {
  liveTest('the directory finds Srikanth by name, and the profile id is the one the app is given', () async {
    final res = await liveAnonymous().dio.get<Map<String, dynamic>>(
      '/mentorship/mentors',
      queryParameters: {'search': 'Srikanth'},
    );
    final ids = (res.data!['data'] as List).map((m) => (m as Map)['id']);
    expect(ids, contains(srikanthId));
  });

  liveTest('the profile reads as the design: hero, stats, career, education, skills', () async {
    final c = await loaded(liveAnonymous());
    final p = c.profile!;

    // The hero.
    expect(p.name, 'Srikanth Sriramagiri');
    expect(p.verified, isTrue, reason: 'Verified Mentor: the profile is APPROVED');
    expect(p.ratingCount, 42);
    expect(p.rating, 5);
    expect(p.yearsExperience, 15);
    expect(p.placeLabel, 'Hyderabad (Hybrid)');
    final line = TextSpan(children: roleLineSpans(p)).toPlainText().replaceAll(' ', ' ');
    expect(line, 'Supply Chain Leader at Microsoft • Ex-Tata Aerospace • BITS Pilani • IIT KGP');
    expect(nextSlot(p.availability, p.timezone), isNotNull, reason: 'Mon, Thu and Sat evenings give a next slot');
    expect(slotDaysLabel(p.availability), 'Mon, Thu, Sat slots');

    // The stats strip.
    expect(p.stats.sessions, '26+');
    expect(p.stats.sessionsBadge, 'Top Mentor');
    expect(p.stats.mentees, '12');
    expect(p.stats.menteesNote, '2 slots open');
    expect(p.languages, ['English', 'Telugu', 'Hindi', 'Kannada']);

    // Career Journey: the design's three roles, newest first.
    expect(p.yearsLabel, '15+ Years Experience');
    expect(p.experience.map((r) => r.title), [
      'APAC Lead, Azure Planning & Execution',
      'Head - Projects, PPC & Industrial Eng.',
      'Senior Consultant - Supply Chain',
    ]);
    expect(p.experience.map((r) => r.organisation), [
      'Microsoft Corporation',
      'Tata Advanced Systems Ltd (TASL)',
      'Infosys Consulting',
    ]);
    expect(p.experience.first.organisationLinked, isTrue);
    expect(p.experience.first.isCurrent, isTrue);
    expect(p.experience.first.years, '2022 - Present');
    expect(p.experience.map((r) => r.place), ['Hyderabad', 'Aerospace & Defense CoE', 'Global Operations Practice']);
    final past = p.experience.skip(1).toList();
    expect(
      [for (final r in past) durationShort(monthsBetween(r.startYear, r.startMonth, r.endYear, r.endMonth))],
      ['10 Yrs', '3 Yrs'],
    );

    // Education: three rows, the BITS row twice, as the design.
    expect(p.education.map((e) => e.batch), ['Batch of 2009 - 2011', 'Batch of 2005 - 2009', 'Batch of 2005 - 2009']);
    expect(p.education.map((e) => e.institution).toSet(), hasLength(2));
    expect(p.education.first.degree, 'Master of Business Administration (MBA)');

    // Technical Mastery & Tools: the design's two captions over competencies and topics.
    expect(p.competenciesLabel, 'Domain Expertise');
    expect(p.topicsLabel, 'Softwares & Frameworks');
    expect(p.competencies, hasLength(4));
    expect(p.topics, [
      'Azure Cloud Planning',
      'Power BI & Analytics',
      'Advanced Financial Modeling',
      'SAP S/4HANA ERP',
    ]);
  });

  liveTest('Offerings read as the design, row by row, then the plan card', () async {
    final c = await loaded(liveAnonymous());
    final rows = c.rows;
    expect(rows.map((o) => o.title), [
      '"What\'s going wrong?" Discovery Call',
      'Personal Interview & GD Preparation',
      'LinkedIn Niche Bible (Strategy Handbook)',
      'AI & ChatGPT Prompts for Resume Building',
      'Statement of Purpose (SOP) Review',
      'MBA Placements Bible (Summer & Finals)',
    ]);
    List<String> tags(MentorOffering o) => [for (final t in o.tags) t.label];
    expect(tags(rows[0]), ['BEST SELLER', '15 Min']);
    expect(tags(rows[1]), ['15 Min • 1:1 Video']);
    expect(tags(rows[2]), ['Digital Guide', 'Instant Download']);
    expect(tags(rows[3]), ['Curated Prompts']);
    expect(tags(rows[5]), ['PDF & Templates']);
    expect(rows.map((o) => o.ctaLabel), [
      'Book Now',
      'Book Now',
      'Purchase Guide',
      'Purchase Guide',
      'Get Guide',
      'Purchase Guide',
    ]);
    expect(rows.map((o) => o.pricePaisa), [0, 0, 900, 900, 0, 900]);
    expect(rows.map((o) => o.compareAtPaisa), [null, null, 49900, 39900, null, 59900]);
    expect(rows[0].previewLabel, 'Inspect 4-session syllabus preview');
    expect(rows[1].previewLabel, isNull);

    // The row filters.
    c.selectFilter(OfferingFilter.oneOnOne);
    expect(c.rows.map((o) => o.id), [rows[0].id, rows[1].id]);
    c.selectFilter(OfferingFilter.resources);
    expect(c.rows, hasLength(4));
    c.selectFilter(OfferingFilter.groupSessions);
    expect(c.rows, isEmpty);

    // The plan card.
    final plan = c.featuredPlan!;
    expect(plan.title, 'Pro Mentorship Tier');
    expect(plan.perMonthPaisa, 1250000);
    expect(plan.seatsNote, 'Only 2 slots left');
    expect(plan.applyLabel, 'Apply for Pro Mentorship');
    expect(plan.inclusions, [
      '2 dedicated live 1:1 strategy calls each month',
      'Unlimited async Slack / WhatsApp query support',
      'Direct resume & LinkedIn profile optimization',
    ]);
  });

  liveTest("the sheet's roadmap: the programme's three terms, each with its own sessions and price", () async {
    final c = await loaded(liveAnonymous());
    final first = c.rows.first;
    final terms = c.variantsOf(first);
    expect(terms.map((t) => t.termMonths), [1, 3, 6]);
    expect(terms.map((t) => t.pricePaisa), [0, 1499900, 2499900]);
    expect(first.id, terms.first.id, reason: 'the row is the shortest term');
    expect(terms.first.roadmap.single.modules.single.steps, [
      'Week 1: Career Diagnostic & Gap Analysis',
      'Week 2: Strategic Positioning & Resume',
      'Week 3: Mock Case Studies & Leadership Drills',
      'Week 4: Action Plan & Referral Cadence',
    ]);
    expect(terms[1].roadmap.single.modules.single.steps, hasLength(12));
    expect(terms.first.roadmap.single.modules.single.badge, 'Month 1');
    expect(terms[2].roadmap.single.modules.single.badge, 'Months 1-6');
    // The plan card is not a row, and the trial is the free 1:1 session.
    expect(c.rows.map((o) => o.id), isNot(contains(c.featuredPlan!.id)));
    expect(c.trialOffering?.title, 'Personal Interview & GD Preparation');
  });

  liveTest('Recommendations: the named testimonial with stars, then the written feedback with its age', () async {
    final c = await loaded(liveAnonymous());
    final reviews = c.reviews;
    expect(reviews.first.name, 'Dev Mangtani');
    expect(reviews.first.subline, 'Operations Analyst');
    expect(reviews.first.rating, 5, reason: "a testimonial reads with the mentor's rating (5.0)");
    expect(reviews.skip(1), hasLength(4));
    for (final r in reviews.skip(1)) {
      expect(r.rating, 5);
      expect(r.createdAt, isNotNull);
      expect(reviewAgo(r.createdAt!), anyOf('1 yr ago', endsWith('mo ago')));
    }
    // "View all 42 verified reviews" is the count the API gives.
    expect(c.profile!.ratingCount, 42);
  });

  liveTest('the bell: the unread count is what the API holds', () async {
    final unread = await repoFor(await signedIn(bharat)).unreadNotifications();
    final api = await signedIn(bharat);
    final held = (await getMap(api, '/notifications/unread-count'))['unread'];
    expect(unread, held);
  });

  liveTest("Verified Mentor and Book Trial: Pooja's profile of Srikanth offers the free session", () async {
    final c = await loaded(await signedIn(pooja));
    expect(c.profile!.viewer?.canRequest, isTrue);
    expect(c.profile!.viewer?.isOwner, isFalse);
    expect(c.trialOffering, isNotNull);
    expect(c.trialOffering!.free, isTrue);
  });

  liveTest('Book Trial (₹0): a session request is kept by the API, shows as Requested, and can be withdrawn', () async {
    final api = await signedIn(pooja);
    final repo = repoFor(api);

    Future<MentorOffering> trial() async => (await loaded(api)).trialOffering!;

    // A request left by an earlier run that stopped half way.
    final before = await trial();
    if (before.myOpenRequestId != null) {
      await api.dio.post<dynamic>('/mentor-services/purchases/${before.myOpenRequestId}/withdraw');
    }
    final offering = await trial();
    expect(offering.myOpenRequestId, isNull);

    String? purchaseId;
    try {
      purchaseId = await repo.requestSession(
        offering,
        topic: 'I want to move from aerospace into cloud logistics and need a plan.',
        mode: 'VIDEO',
        preferredTimes: 'Weekday evenings, IST',
      );
      expect(purchaseId, isNotNull);

      // Read back: the purchase exists as a request, and the screen's data marks the row.
      final purchase = await getMap(api, '/mentor-services/purchases/$purchaseId');
      expect(purchase['status'], 'REQUESTED');
      final request = purchase['request'] as Map<String, dynamic>;
      expect(request['topic'], 'I want to move from aerospace into cloud logistics and need a plan.');
      expect(request['preferredTimes'], 'Weekday evenings, IST');
      expect(request['mode'], 'VIDEO');
      final after = await loaded(api);
      expect(after.trialOffering!.myOpenRequestId, purchaseId);

      // Asking again is refused, in the API's words.
      await expectLater(
        repo.requestSession(offering, topic: 'A second request for the very same session, right away.', mode: 'VIDEO'),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', anyOf(400, 409))),
      );
    } finally {
      if (purchaseId != null) {
        await api.dio.post<dynamic>('/mentor-services/purchases/$purchaseId/withdraw');
      }
    }

    // Withdrawn: nothing open, and the trial can be asked for again.
    final purchase = await getMap(api, '/mentor-services/purchases/$purchaseId');
    expect(purchase['status'], 'CANCELLED');
    expect((await loaded(api)).trialOffering!.myOpenRequestId, isNull);
  });

  liveTest('the session form needs a number: refused without one, kept with one, and undone', () async {
    final api = await signedIn(dev);
    // A run that stopped half way may have left a number on the account.
    if (await phoneOf(api) != null) await api.dio.patch<dynamic>('/users/me', data: {'phone': ''});
    final repo = repoFor(api);
    expect(await repo.hasPhone(), isFalse, reason: 'the form asks for a number when the profile has none');

    final c = await loaded(api);
    final offering = c.trialOffering!;
    String? purchaseId;
    try {
      // The API refuses and says why; the form shows this sentence and reveals its phone field.
      Object? refusal;
      try {
        await repo.requestSession(
          offering,
          topic: 'I want to move from aerospace into cloud logistics and need a plan.',
          mode: 'VIDEO',
        );
      } catch (e) {
        refusal = e;
      }
      expect(refusal, isA<ApiError>());
      expect((refusal! as ApiError).message, phoneNeeded);
      expect(isPhoneRefusal((refusal as ApiError).message), isTrue);
      expect(await phoneOf(api), isNull, reason: 'a refused request saves nothing');

      // Sent with a number: the request is made and the number is saved with it.
      purchaseId = await repo.requestSession(
        offering,
        topic: 'I want to move from aerospace into cloud logistics and need a plan.',
        mode: 'VIDEO',
        phone: '+919811111111',
      );
      expect(purchaseId, isNotNull);
      expect(await phoneOf(api), '+919811111111');
      expect(await repo.hasPhone(), isTrue);
    } finally {
      if (purchaseId != null) {
        await api.dio.post<dynamic>('/mentor-services/purchases/$purchaseId/withdraw');
      }
      await api.dio.patch<dynamic>('/users/me', data: {'phone': ''});
    }
    expect(await repo.hasPhone(), isFalse);
    expect((await getMap(api, '/mentor-services/purchases/$purchaseId'))['status'], 'CANCELLED');
  });

  liveTest('a programme asked for is kept, shows as Requested, refuses a second ask, and is withdrawn', () async {
    final api = await signedIn(pooja);
    final repo = repoFor(api);

    Future<List<Map<String, dynamic>>> waiting() async => [
      for (final s in await getList(api, '/mentor-plans/subscriptions/mine'))
        if (s['status'] == 'PENDING_MENTOR' || s['status'] == 'PENDING_PAYMENT') s,
    ];

    // Left behind by an earlier run that stopped half way.
    for (final s in await waiting()) {
      await api.dio.post<dynamic>('/mentor-plans/subscriptions/${s['id']}/cancel', data: {});
    }

    // Both terms: the free one the row opens with, and the paid 3 Months the toggle can switch to.
    final c = await loaded(api);
    final terms = c.variantsOf(c.rows.first);
    final asked = <String>[];
    try {
      for (final term in [terms[0], terms[1]]) {
        final outcome = await repo.buy(c.profile!, term);
        expect(outcome.state, CheckoutState.requested, reason: '${term.termMonths} month(s): ${outcome.message}');

        final mine = await waiting();
        final sub = mine.firstWhere((s) => s['planId'] == term.id);
        asked.add(sub['id'] as String);
        expect(sub['status'], 'PENDING_MENTOR');
        expect(sub['pricePaisa'], term.pricePaisa, reason: "the price of the term that was on show");

        // The screen's data now marks that term's row.
        final again = await loaded(api);
        expect(again.offerings.firstWhere((o) => o.id == term.id).myOpenRequestId, sub['id']);

        // A second ask for the same term is refused with the API's sentence (never shown as a success).
        final refused = await again.buy(again.offerings.firstWhere((o) => o.id == term.id));
        expect(refused.state, CheckoutState.refused);
        expect(refused.message, contains('already asked for this program'));
      }
    } finally {
      for (final id in asked) {
        await api.dio.post<dynamic>('/mentor-plans/subscriptions/$id/cancel', data: {});
      }
    }
    // Withdrawn: not waiting any more, and the row is open again.
    expect(await waiting(), isEmpty);
    final after = await loaded(api);
    for (final term in [terms[0], terms[1]]) {
      expect(after.offerings.firstWhere((o) => o.id == term.id).myOpenRequestId, isNull);
    }
    final subs = await getList(api, '/mentor-plans/subscriptions/mine');
    for (final id in asked) {
      expect(subs.firstWhere((s) => s['id'] == id)['status'], 'CANCELLED');
    }
  });

  liveTest('Get Guide: a free resource is taken in the app, once (the API keeps the purchase)', () async {
    // NOT undone: the API has no way to give a free resource back. Taking it again returns the same
    // purchase, so the test can run again without piling anything up.
    final api = await signedIn(pooja);
    final c = await loaded(api);
    final guide = c.rows.firstWhere((o) => o.kind == OfferingKind.resource && o.free);
    expect(guide.ctaLabel, 'Get Guide');

    final first = await c.buy(guide);
    expect(first.state, CheckoutState.completed, reason: first.message);
    expect(first.message, contains('Added to your purchases'));

    Future<List<Map<String, dynamic>>> mine() async => (await getList(
      api,
      '/mentor-services/purchases/mine?limit=100',
    )).where((p) => p['serviceId'] == guide.id).toList();
    final kept = await mine();
    expect(kept, hasLength(1));
    expect(kept.single['status'], 'FULFILLED');

    final second = await c.buy(guide);
    expect(second.state, CheckoutState.completed);
    expect(await mine(), hasLength(1), reason: 'the same purchase, not another');
  });

  liveTest('Purchase Guide (paid) and Apply for Pro Mentorship: the website, and nothing is bought here', () async {
    final api = await signedIn(pooja);
    final c = await loaded(api);
    final repo = repoFor(api);
    Future<int> purchases() async => (await getList(api, '/mentor-services/purchases/mine?limit=100')).length;
    Future<int> subscriptions() async => (await getList(api, '/mentor-plans/subscriptions/mine')).length;
    final purchasesBefore = await purchases();
    final subscriptionsBefore = await subscriptions();

    final guide = c.rows.firstWhere((o) => o.kind == OfferingKind.resource && !o.free);
    expect(guide.ctaLabel, 'Purchase Guide');
    final bought = await repo.buy(c.profile!, guide);
    expect(bought.state, CheckoutState.website);
    expect(bought.sitePath, '/mentorship/mentors/$srikanthId?book=${guide.id}');

    final plan = c.featuredPlan!;
    final applied = await repo.buy(c.profile!, plan);
    expect(applied.state, CheckoutState.website);
    expect(applied.sitePath, '/mentorship/mentors/$srikanthId');

    expect(await purchases(), purchasesBefore);
    expect(await subscriptions(), subscriptionsBefore);
  });

  liveTest('Send Message: a mentor you are paired with opens the thread; with no pairing there is none', () async {
    final paired = await loaded(await signedIn(yash));
    expect(paired.profile!.viewer?.mentorshipId, isNotNull, reason: 'Yash has a live pairing with Srikanth');
    final id = await paired.openConversation();
    expect(id, isNotNull);
    expect(id, isNotEmpty);
    expect(await paired.openConversation(), id, reason: 'the pairing has one thread');

    final stranger = await loaded(await signedIn(pooja));
    expect(stranger.profile!.viewer?.mentorshipId, isNull);
    expect(await stranger.openConversation(), isNull, reason: 'no thread to open: Send Message asks instead');
  });

  liveTest('the mentoring request (Send Message with no pairing): kept by the API, pending, then withdrawn', () async {
    final api = await signedIn(pooja);
    final repo = repoFor(api);
    final before = await loaded(api);
    expect(before.profile!.viewer?.canRequest, isTrue);

    String? requestId;
    try {
      await repo.requestMentoring(
        before.profile!,
        message: 'Please mentor me on moving from operations into supply planning roles.',
      );
      final after = await loaded(api);
      requestId = after.profile!.viewer?.pendingRequestId;
      expect(requestId, isNotNull, reason: 'the profile now says the request is with the mentor');
      expect(after.profile!.viewer?.canRequest, isFalse);
      expect(after.profile!.viewer?.blocker, AskBlocker.requestPending);
    } finally {
      if (requestId != null) {
        await api.dio.post<dynamic>('/mentorship/requests/$requestId/withdraw');
      }
    }
    final reset = await loaded(api);
    expect(reset.profile!.viewer?.pendingRequestId, isNull);
    expect(reset.profile!.viewer?.canRequest, isTrue);
  });

  liveTest('the request forms refuse a short message with the API, not just on the phone', () async {
    final api = await signedIn(pooja);
    final repo = repoFor(api);
    final c = await loaded(api);
    // The limits the forms check first are the API's own: a short topic or message is refused by it too.
    Future<ApiError> refusal(Future<Object?> call) async {
      try {
        await call;
      } on DioException catch (e) {
        return ApiError.from(e);
      } on ApiError catch (e) {
        return e;
      }
      fail('the API should have refused');
    }

    final topic = await refusal(repo.requestSession(c.trialOffering!, topic: 'too short', mode: 'VIDEO'));
    expect(topic.statusCode, 400);
    final message = await refusal(repo.requestMentoring(c.profile!, message: 'too short'));
    expect(message.statusCode, 400);
  });
}
