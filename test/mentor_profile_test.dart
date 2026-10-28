import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_client.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/auth/token_store.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/mentor_profile/api_mentor_profile_repository.dart';
import 'package:icr_mobile/features/mentor_profile/demo_mentor_profile_repository.dart';
import 'package:icr_mobile/features/mentor_profile/mentor_profile_controller.dart';
import 'package:icr_mobile/features/mentor_profile/mentor_profile_format.dart';
import 'package:icr_mobile/features/mentor_profile/mentor_profile_models.dart';
import 'package:icr_mobile/features/mentor_profile/mentor_profile_navigation.dart';
import 'package:icr_mobile/features/mentor_profile/mentor_profile_repository.dart';
import 'package:icr_mobile/features/mentor_profile/mentor_profile_screen.dart';
import 'package:icr_mobile/features/mentor_profile/offering_sheet.dart';
import 'package:icr_mobile/features/mentor_profile/widgets/profile_hero.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'helpers/fonts.dart';

class _NoTokens extends TokenStore {
  @override
  Future<String?> accessToken() async => 'token';
  @override
  Future<String?> refreshToken() async => null;
}

/// Answers each route from a table and records the calls and their bodies.
class _Api implements HttpClientAdapter {
  _Api(this.routes);

  final Map<String, Object Function(RequestOptions options)> routes;
  final List<String> calls = [];
  final Map<String, Object?> bodies = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    calls.add(key);
    bodies[key] = options.data;
    final handler = routes[key];
    if (handler == null) return ResponseBody.fromString('{"message":"Not found"}', 404, headers: _json);
    final result = handler(options);
    if (result is (int, String)) return ResponseBody.fromString(result.$2, result.$1, headers: _json);
    return ResponseBody.fromString(jsonEncode(result), 200, headers: _json);
  }

  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  void close({bool force = false}) {}
}

ApiClient _client(_Api api) {
  final client = ApiClient(tokens: _NoTokens(), baseUrl: 'http://api.test/api/v1');
  client.dio.httpClientAdapter = api;
  return client;
}

final _profileJson = <String, Object?>{
  'id': 'm1',
  'user': {'id': 'u1', 'firstName': 'Srikanth', 'lastName': 'Sriramagiri', 'avatarUrl': '/uploads/s.jpg'},
  'coverImage': '/uploads/cover.jpg',
  'headline': 'Ex-Tata Aerospace • BITS Pilani',
  'bioHtml': '<p>Result-oriented professional.</p><p>Founded supply planning &amp; the CoE.</p>',
  'yearsExperience': 15,
  'city': 'Hyderabad',
  'preferredModes': ['VIDEO', 'IN_PERSON'],
  'languages': ['English', 'Telugu'],
  'competencies': ['Supply Chain Optimization'],
  'topics': ['SAP S/4HANA ERP'],
  'rating': 4.96,
  'ratingCount': 42,
  'sessionsCompleted': 26,
  'menteesHelped': 12,
  'isTopMentor': true,
  'openSlots': 2,
  'capacity': 4,
  'status': 'APPROVED',
  'career': {
    'currentRole': {'title': 'Supply Chain Leader', 'organisation': 'Microsoft'},
  },
  'experience': [
    {
      'title': 'APAC Lead',
      'organisation': 'Microsoft Corporation',
      'company': {'id': 'c1'},
      'startYear': 2022,
      'isCurrent': true,
      'city': 'Hyderabad',
      'description': 'Orchestrating cloud capacity.',
    },
  ],
  'education': [
    {'institution': 'IIT Kharagpur', 'degree': 'MBA', 'fieldOfStudy': 'Operations', 'startYear': 2009, 'endYear': 2011},
  ],
  'availabilityBlocks': [
    {'weekday': 1, 'startMin': 1140, 'endMin': 1260},
    {'weekday': 4, 'startMin': 1140, 'endMin': 1260},
  ],
  'timezone': 'Asia/Kolkata',
  'viewer': {'isOwner': false, 'canRequest': true, 'blockedReason': null, 'blocker': null},
};

Map<String, Object Function(RequestOptions)> _routes({Map<String, Object?>? profile}) {
  final soon = DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String();
  return {
    'GET /mentorship/mentors/m1': (_) => profile ?? _profileJson,
    'GET /mentor-services/mentors/m1': (_) => {
      'live': true,
      'serviceRating': 4.8,
      'serviceRatingCount': 12,
      'services': [
        {
          'id': 's1',
          'type': 'ONE_ON_ONE',
          'title': 'Discovery Call',
          'blurb': 'Diagnostic session.',
          'durationMin': 15,
          'pricePaisa': 0,
          'isBestSeller': true,
          'rating': 4.9,
          'ratingCount': 10,
          'salesCount': 8,
        },
        {
          'id': 's2',
          'type': 'RESOURCE',
          'title': 'LinkedIn Bible',
          'pricePaisa': 900,
          'compareAtPaisa': 49900,
          'fileName': 'bible.pdf',
        },
        {'id': 's3', 'type': 'QUERY', 'title': 'SOP Review', 'pricePaisa': 0, 'slaHours': 24},
        {'id': 's4', 'type': 'GROUP_SESSION', 'title': 'Hidden seat', 'pricePaisa': 0},
      ],
    },
    'GET /mentor-plans/by-mentor/m1': (_) => [
      {
        'id': 'pl1',
        'kind': 'RECURRING',
        'title': 'Pro Tier',
        'pricePaisa': 1250000,
        'billingPeriodMonths': 1,
        'sessionsPerMonth': 2,
        'perMonthPaisa': 1250000,
        'inclusions': ['Two calls a month', 'Resume review'],
        'modules': [],
      },
      {
        'id': 'pl2',
        'kind': 'CURRICULUM',
        'title': 'Career Reset',
        'pricePaisa': 0,
        'billingPeriodMonths': 3,
        'accessMonths': 3,
        'totalSessions': 2,
        'modules': [
          {'title': 'Diagnose'},
          {'title': 'Plan'},
        ],
      },
    ],
    'GET /mentorship/group-sessions': (_) => {
      'data': [
        {
          'id': 'g1',
          'title': 'Resume clinic',
          'status': 'SCHEDULED',
          'scheduledAt': soon,
          'durationMin': 60,
          'seatsLeft': 5,
          'pricePaisa': 0,
        },
      ],
      'meta': {},
    },
    'GET /mentorship/testimonials': (_) => [
      {
        'id': 't1',
        'authorName': 'Dev Mangtani',
        'authorTitle': 'Operations Analyst',
        'quote': 'Exceptionally structured.',
        'mentorProfileId': 'm1',
      },
      {'id': 't2', 'authorName': 'Someone', 'quote': 'About another mentor.', 'mentorProfileId': 'other'},
    ],
    'GET /mentorship/mentors/m1/feedback': (_) => [
      {'id': 'f1', 'rating': 5, 'comment': 'Very clear.', 'createdAt': '2026-01-01T00:00:00.000Z'},
      {'id': 'f2', 'rating': 4, 'comment': null, 'createdAt': '2026-01-02T00:00:00.000Z'},
    ],
    'GET /notifications/unread-count': (_) => {'unread': 3},
    'GET /auth/me': (_) => {
      'user': {'phone': '+919800000000'},
    },
  };
}

/// The demo source, except that asking is refused.
class _Refusing extends DemoMentorProfileRepository {
  @override
  Future<void> requestMentoring(MentorProfile mentor, {required String message, String? phone}) async =>
      throw ApiError('No requests today.');

  @override
  Future<String?> requestSession(
    MentorOffering offering, {
    required String topic,
    required String mode,
    String? preferredTimes,
    String? phone,
  }) async => throw ApiError('The mentor is away.');
}

/// The fixture mentor with no network pictures (a widget test cannot fetch them).
Map<String, Object?> _plainProfile([Map<String, Object?> extra = const {}]) => {
  ..._profileJson,
  'coverImage': null,
  'user': {'id': 'u1', 'firstName': 'Srikanth', 'lastName': 'Sriramagiri', 'avatarUrl': null},
  ...extra,
};

/// Records the addresses the app hands to the browser (the website's pages).
List<String> _launches(WidgetTester tester) {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final urls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'launch') urls.add((call.arguments as Map)['url'] as String);
    return true;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
  return urls;
}

/// Records where the page hands over to the rest of the app, instead of opening the app's screens.
class _Hops {
  final events = <String>[];

  MentorProfileNavigation get navigation => MentorProfileNavigation(
    onGoals: (c) => events.add('goals'),
    onPurchases: (c) => events.add('purchases'),
    onPairing: (c, id) => events.add('pairing:$id'),
    onConversation: (c, id) => events.add('conversation:$id'),
    onNotifications: (c) => events.add('notifications'),
    onEditMentorProfile: (c) => events.add('editMentorProfile'),
  );
}

const _phoneNeeded = (400, '{"message":"Add a mobile number so your mentor can reach you."}');

/// The demo source with no number on file, recording what the session request was sent with.
class _NoPhone extends DemoMentorProfileRepository {
  final sent = <String?>[];

  @override
  Future<bool> hasPhone() async => false;

  @override
  Future<String?> requestSession(
    MentorOffering offering, {
    required String topic,
    required String mode,
    String? preferredTimes,
    String? phone,
  }) {
    sent.add(phone);
    return super.requestSession(offering, topic: topic, mode: mode, preferredTimes: preferredTimes, phone: phone);
  }
}

/// A programme listed in three terms, beside the ongoing plan, as the seeded mentor sells it.
List<Object?> _termPlans() => [
  {
    'id': 'p1m',
    'kind': 'CURRICULUM',
    'title': 'Discovery',
    'pricePaisa': 0,
    'billingPeriodMonths': 1,
    'accessMonths': 1,
    'totalSessions': 2,
    'sessionsPerMonth': 4,
    'sessionDurationMin': 15,
    'subscribersCount': 6,
    'modules': [
      {'title': 'Week 1: Diagnose'},
      {'title': 'Week 2: Plan'},
    ],
  },
  {
    'id': 'p3m',
    'kind': 'CURRICULUM',
    'title': 'Discovery',
    'pricePaisa': 1499900,
    'billingPeriodMonths': 3,
    'accessMonths': 3,
    'totalSessions': 3,
    'sessionsPerMonth': 4,
    'sessionDurationMin': 30,
    'modules': [
      {'title': 'Diagnose'},
      {'title': 'Plan'},
      {'title': 'Execute'},
    ],
  },
  {
    'id': 'p6m',
    'kind': 'CURRICULUM',
    'title': 'Discovery',
    'pricePaisa': 2499900,
    'billingPeriodMonths': 6,
    'accessMonths': 6,
    'totalSessions': 1,
    'sessionsPerMonth': 2,
    'modules': [
      {'title': 'Everything'},
    ],
  },
  {
    'id': 'pro',
    'kind': 'RECURRING',
    'title': 'Pro Mentorship Tier',
    'pricePaisa': 1250000,
    'billingPeriodMonths': 1,
    'sessionsPerMonth': 2,
    'perMonthPaisa': 1250000,
    'inclusions': ['Two calls a month'],
    'modules': [],
  },
];

void main() {
  setUpAll(loadAppFonts);

  group('formatting', () {
    test('rupees use Indian grouping and drop empty paise', () {
      expect(inr(1250000), '₹12,500');
      expect(inr(12500000), '₹1,25,000');
      expect(inr(49900), '₹499');
      expect(inr(50), '₹0.50');
      expect(priceLabel(0), 'FREE');
      expect(priceLabel(900), '₹9');
    });

    test('a role reads as the design writes its length', () {
      expect(durationLabel(28), '2 yrs 4 mos');
      expect(durationLabel(6), '6 mos');
      expect(durationShort(120), '10 Yrs');
      expect(durationShort(8), '8 mos');
      expect(monthsBetween(2012, null, 2022, null), 132);
    });

    test("the next slot is read in the mentor's own zone", () {
      const blocks = [
        AvailabilityBlock(weekday: 1, startMin: 19 * 60, endMin: 21 * 60),
        AvailabilityBlock(weekday: 4, startMin: 19 * 60, endMin: 21 * 60),
      ];
      // Sunday 25 Oct 2026, 12:00 UTC is 17:30 in Kolkata: Monday is tomorrow.
      final sunday = DateTime.utc(2026, 10, 25, 12);
      final slot = nextSlot(blocks, 'Asia/Kolkata', sunday)!;
      expect(slot.daysAhead, 1);
      expect(slot.label, 'Next Slot: Tomorrow, 7:00 PM');
      // Monday 18:00 in Kolkata: today's block has not begun yet.
      final monday = DateTime.utc(2026, 10, 26, 12, 30);
      expect(nextSlot(blocks, 'Asia/Kolkata', monday)!.label, 'Next Slot: Today, 7:00 PM');
      // Monday 20:00 in Kolkata: the block is running, so the next start is Thursday.
      final late = DateTime.utc(2026, 10, 26, 14, 30);
      expect(nextSlot(blocks, 'Asia/Kolkata', late)!.label, 'Next Slot: Thu, 7:00 PM');
      expect(nextSlot(const [], 'Asia/Kolkata'), isNull);
      expect(slotDaysLabel(blocks), 'Mon, Thu slots');
    });

    test('a bio becomes paragraphs of plain text', () {
      expect(bioParagraphs('<p>One &amp; two.</p><p>Three.</p>'), ['One & two.', 'Three.']);
      expect(bioParagraphs('First.\n\nSecond.'), ['First.', 'Second.']);
      expect(bioParagraphs(null), isEmpty);
    });

    test('a review is dated coarsely', () {
      final now = DateTime(2026, 10, 22);
      expect(reviewAgo(now.subtract(const Duration(days: 400)), now), '1 yr ago');
      expect(reviewAgo(now.subtract(const Duration(days: 95)), now), '3 mo ago');
      expect(reviewAgo(now.subtract(const Duration(days: 4)), now), '4d ago');
    });
  });

  group('the API source', () {
    test('maps the public profile', () async {
      final api = _Api(_routes());
      final profile = await ApiMentorProfileRepository(api: _client(api)).profile('m1');
      expect(profile.name, 'Srikanth Sriramagiri');
      expect(profile.roleTitle, 'Supply Chain Leader');
      expect(profile.roleOrganisation, 'Microsoft');
      expect(profile.photo?.url, 'http://api.test/uploads/s.jpg');
      expect(profile.cover?.url, 'http://api.test/uploads/cover.jpg');
      expect(profile.placeLabel, 'Hyderabad (Hybrid)');
      expect(profile.modeKeys, ['VIDEO', 'IN_PERSON']);
      expect(profile.stats.sessions, '26+');
      expect(profile.stats.sessionsBadge, 'Top Mentor');
      expect(profile.stats.menteesCaption, 'Mentees Helped');
      expect(profile.stats.menteesNote, '2 slots open');
      expect(profile.experience.single.organisationLinked, isTrue);
      expect(profile.experience.single.years, '2022 - Present');
      expect(profile.education.single.batch, 'Batch of 2009 - 2011');
      expect(profile.availability, hasLength(2));
      expect(profile.viewer?.canRequest, isTrue);
      expect(profile.verified, isTrue);
      expect(profile.yearsLabel, '15+ Years Experience');
      expect(profile.topicsLabel, 'Softwares & Frameworks');
    });

    test('a banner that is only a preset key is no picture', () async {
      final api = _Api(_routes(profile: {..._profileJson, 'coverImage': 'preset-3'}));
      final profile = await ApiMentorProfileRepository(api: _client(api)).profile('m1');
      expect(profile.cover, isNull);
    });

    test('lists what the mentor sells, 1:1 first, and drops what a buyer never sees', () async {
      final api = _Api(_routes());
      final repo = ApiMentorProfileRepository(api: _client(api));
      final profile = await repo.profile('m1');
      final offerings = await repo.offerings(profile);
      // The programme (1:1 mentoring) leads, a single session follows it.
      expect(offerings.map((o) => o.id), ['pl2', 's1', 'pl1', 's2', 's3', 'group-g1']);
      expect(api.calls, contains('GET /mentorship/group-sessions'));

      final call = offerings[1];
      expect(call.kind, OfferingKind.oneOnOne);
      expect(call.free, isTrue);
      // Beside BEST SELLER the length stands alone, as the design draws it.
      expect(call.tags.map((t) => t.label), ['BEST SELLER', '15 Min']);
      expect(call.ctaLabel, 'Book Now');

      final program = offerings.first;
      expect(program.kind, OfferingKind.program);
      expect(program.ctaLabel, 'Book Now');
      expect(program.tags.map((t) => t.label), ['2 Sessions']);
      expect(program.previewLabel, 'Inspect 2-session syllabus preview');
      expect(program.roadmap.single.label, '3 Months');
      expect(program.roadmap.single.modules.single.title, '2-session syllabus');
      expect(program.roadmap.single.modules.single.badge, 'Months 1-3');
      expect(program.roadmap.single.modules.single.steps, ['Session 1: Diagnose', 'Session 2: Plan']);

      final plan = offerings[2];
      expect(plan.kind, OfferingKind.plan);
      expect(plan.perMonthPaisa, 1250000);
      expect(plan.inclusions, ['Two calls a month', 'Resume review']);
      expect(plan.seatsNote, 'Only 2 slots left');
      expect(plan.applyLabel, 'Apply for Pro');

      final guide = offerings[3];
      expect(guide.kind, OfferingKind.resource);
      expect(guide.pricePaisa, 900);
      expect(guide.compareAtPaisa, 49900);
      // A real file kind names itself; the "Instant Download" promise is for a file we cannot name.
      expect(guide.tags.map((t) => t.label), ['PDF Guide']);
      expect(guide.ctaLabel, 'Purchase Guide');

      expect(offerings[4].tags.single.label, 'Async Query • 24h TAT');
      expect(offerings.last.kind, OfferingKind.groupSession);
      expect(offerings.last.seatsLeft, 5);
    });

    test('a storefront that is not live sells no services', () async {
      final routes = _routes();
      routes['GET /mentor-services/mentors/m1'] = (_) => {'live': false, 'services': []};
      final repo = ApiMentorProfileRepository(api: _client(_Api(routes)));
      final offerings = await repo.offerings(await repo.profile('m1'));
      expect(offerings.map((o) => o.id), ['pl2', 'pl1', 'group-g1']);
    });

    test('reviews: named testimonials for this mentor, then written mentee feedback', () async {
      final repo = ApiMentorProfileRepository(api: _client(_Api(_routes())));
      final reviews = await repo.reviews(await repo.profile('m1'));
      expect(reviews.map((r) => r.id), ['t-t1', 'f-f1']);
      expect(reviews.first.name, 'Dev Mangtani');
      expect(reviews.last.name, 'A mentee');
      expect(reviews.last.rating, 5);
      // A curated testimonial has no rating of its own: it reads with the mentor's (4.96 rounds to five stars).
      expect(reviews.first.rating, 5);
      expect(reviews.first.createdAt, isNull);
    });

    test('a testimonial is dated once the API sends a date, and starless for an unrated mentor', () async {
      final routes = _routes();
      routes['GET /mentorship/testimonials'] = (_) => [
        {
          'id': 't1',
          'authorName': 'Dev Mangtani',
          'authorTitle': 'Operations Analyst',
          'quote': 'Exceptionally structured.',
          'mentorProfileId': 'm1',
          'createdAt': '2025-09-01T00:00:00.000Z',
        },
      ];
      final dated = await ApiMentorProfileRepository(
        api: _client(_Api(routes)),
      ).reviews(await ApiMentorProfileRepository(api: _client(_Api(routes))).profile('m1'));
      expect(dated.first.createdAt, DateTime.utc(2025, 9, 1));

      final unrated = {..._profileJson, 'rating': 0, 'ratingCount': 0};
      final repo = ApiMentorProfileRepository(api: _client(_Api(_routes(profile: unrated))));
      final reviews = await repo.reviews(await repo.profile('m1'));
      expect(reviews.first.rating, isNull);
    });

    test("asks for a session and for free mentoring with the API's bodies", () async {
      final routes = _routes()
        ..['POST /mentor-services/s1/request'] = ((_) => {'id': 'pur1'})
        ..['POST /mentorship/requests'] = ((_) => {'id': 'req1'});
      final api = _Api(routes);
      final repo = ApiMentorProfileRepository(api: _client(api));
      final profile = await repo.profile('m1');
      final offerings = await repo.offerings(profile);

      final id = await repo.requestSession(
        offerings.firstWhere((o) => o.id == 's1'),
        topic: ' I want to move from aerospace to cloud logistics ',
        mode: 'VIDEO',
        preferredTimes: 'Evenings',
      );
      expect(id, 'pur1');
      expect(api.bodies['POST /mentor-services/s1/request'], {
        'topic': 'I want to move from aerospace to cloud logistics',
        'mode': 'VIDEO',
        'preferredTimes': 'Evenings',
      });

      await repo.requestMentoring(
        profile,
        message: 'Please mentor me on supply chain careers, thank you.',
        phone: '+919811111111',
      );
      expect(api.bodies['POST /mentorship/requests'], {
        'mentorProfileId': 'm1',
        'message': 'Please mentor me on supply chain careers, thank you.',
        'phone': '+919811111111',
      });
    });

    test("buying: free things complete, programmes are requested, paid checkout is the website's", () async {
      final routes = _routes()
        ..['POST /mentor-services/s2/checkout'] = ((_) => {'devActivated': true, 'purchaseId': 'p'})
        ..['POST /mentor-plans/pl2/request'] = ((_) => {
          'ok': true,
          'subscriptionId': 'sub',
          'status': 'PENDING_MENTOR',
        });
      final api = _Api(routes);
      final repo = ApiMentorProfileRepository(api: _client(api));
      final profile = await repo.profile('m1');
      final offerings = {for (final o in await repo.offerings(profile)) o.id: o};

      final program = await repo.buy(profile, offerings['pl2']!, phone: '+919811111111');
      expect(program.state, CheckoutState.requested);
      expect(api.bodies['POST /mentor-plans/pl2/request'], {'phone': '+919811111111'});

      final paidPlan = await repo.buy(profile, offerings['pl1']!);
      expect(paidPlan.state, CheckoutState.website);
      expect(api.calls.where((c) => c.contains('/pl1/')), isEmpty);

      final paidGuide = await repo.buy(profile, offerings['s2']!);
      expect(paidGuide.state, CheckoutState.website);
      expect(paidGuide.sitePath, '/mentorship/mentors/m1?book=s2');

      final seat = await repo.buy(profile, offerings['group-g1']!);
      expect(seat.sitePath, '/mentorship/groups/g1');
    });

    test("opens a live pairing's thread", () async {
      final profile = {
        ..._profileJson,
        'viewer': {'isOwner': false, 'canRequest': false, 'blocker': 'ALREADY_MATCHED', 'mentorshipId': 'ms1'},
      };
      final routes = _routes(profile: profile)
        ..['POST /mentorship/ms1/conversation'] = ((_) => {'conversationId': 'c9'});
      final repo = ApiMentorProfileRepository(api: _client(_Api(routes)));
      final mentor = await repo.profile('m1');
      expect(mentor.viewer?.blocker, AskBlocker.alreadyMatched);
      expect(await repo.openConversation(mentor), 'c9');
    });
  });

  group('the controller', () {
    Future<MentorProfileController> loaded(MentorProfileRepository repo) async {
      final c = MentorProfileController(repository: repo, mentorId: 'demo-srikanth');
      await c.load();
      return c;
    }

    test('splits the featured plan from the rows and filters them', () async {
      final c = await loaded(DemoMentorProfileRepository());
      expect(c.featuredPlan?.id, 'demo-pro-tier');
      expect(c.rows.map((o) => o.id), [
        'demo-discovery',
        'demo-interview',
        'demo-linkedin',
        'demo-prompts',
        'demo-sop',
        'demo-mba',
      ]);
      c.selectFilter(OfferingFilter.oneOnOne);
      expect(c.rows.map((o) => o.id), ['demo-discovery', 'demo-interview']);
      c.selectFilter(OfferingFilter.resources);
      expect(c.rows, hasLength(4));
      c.selectFilter(OfferingFilter.groupSessions);
      expect(c.rows, isEmpty);
      expect(c.filters, OfferingFilter.values);
      expect(c.trialOffering?.id, 'demo-discovery');
      expect(c.unread, 1);
      expect(c.reviews.single.name, 'Dev Mangtani');
    });

    test('a refused mentoring request rolls the button back and says why', () async {
      final c = await loaded(_Refusing());
      expect(c.profile!.viewer!.canRequest, isTrue);
      final message = await c.requestMentoring(message: 'Please mentor me on supply chain careers.');
      expect(message, 'No requests today.');
      expect(c.profile!.viewer!.canRequest, isTrue);
      expect(c.profile!.viewer!.pendingRequestId, isNull);
    });

    test('a sent mentoring request leaves the viewer pending', () async {
      final c = await loaded(DemoMentorProfileRepository());
      expect(await c.requestMentoring(message: 'Please mentor me on supply chain careers.'), isNull);
      expect(c.profile!.viewer!.blocker, AskBlocker.requestPending);
    });

    test('a refused session request leaves the offering open', () async {
      final c = await loaded(_Refusing());
      final call = c.trialOffering!;
      final message = await c.requestSession(call, topic: 'x' * 30, mode: 'VIDEO');
      expect(message, 'The mentor is away.');
      expect(c.offerings.firstWhere((o) => o.id == call.id).myOpenRequestId, isNull);
    });

    test('a sent session request marks the offering requested', () async {
      final c = await loaded(DemoMentorProfileRepository());
      expect(await c.requestSession(c.trialOffering!, topic: 'x' * 30, mode: 'VIDEO'), isNull);
      expect(c.offerings.firstWhere((o) => o.id == 'demo-discovery').myOpenRequestId, isNotNull);
    });

    test("a refused purchase is a refusal with the API's sentence, never a success", () async {
      final routes = _routes()
        ..['POST /mentor-plans/pl2/request'] = ((_) => (400, '{"message":"You have already asked for this program."}'))
        ..['POST /mentor-services/s2/checkout'] = ((_) => {'devActivated': true});
      final repo = ApiMentorProfileRepository(api: _client(_Api(routes)));
      final c = MentorProfileController(repository: repo, mentorId: 'm1');
      await c.load();
      final program = c.offerings.firstWhere((o) => o.id == 'pl2');
      final refused = await c.buy(program, phone: '+919811111111');
      expect(refused.state, CheckoutState.refused);
      expect(refused.message, 'You have already asked for this program.');
      // The row stays open for another try.
      expect(c.offerings.firstWhere((o) => o.id == 'pl2').myOpenRequestId, isNull);
    });

    test("a profile that cannot load keeps the API's sentence", () async {
      final repo = ApiMentorProfileRepository(api: _client(_Api({})));
      final c = MentorProfileController(repository: repo, mentorId: 'nobody');
      await c.load();
      expect(c.profile, isNull);
      expect(c.error, 'Not found');
    });
  });

  group('the screen', () {
    Future<MentorProfileController> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(780, 4600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final controller = MentorProfileController(repository: DemoMentorProfileRepository(), mentorId: 'demo-srikanth');
      await tester.runAsync(controller.load);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(
            value: controller,
            child: MentorProfileScreen(mentorId: controller.mentorId, onBack: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('draws the overview, then the offerings, and opens an offering', (tester) async {
      await pump(tester);
      expect(find.text('Srikanth Sriramagiri'), findsOneWidget);
      expect(find.text('Book Trial (₹0)'), findsOneWidget);
      expect(find.text('Next Slot: Tomorrow, 7:00 PM'), findsOneWidget);
      expect(find.text('Career Journey'), findsOneWidget);

      await tester.tap(find.text('Offerings'));
      await tester.pumpAndSettle();
      expect(find.text('Book Now'), findsNWidgets(2));
      expect(find.text('Purchase Guide'), findsNWidgets(3));
      expect(find.text('Apply for Pro Mentorship'), findsOneWidget);

      await tester.tap(find.text('"What\'s going wrong?" Discovery Call'));
      await tester.pumpAndSettle();
      expect(find.text('Curriculum Roadmap'), findsOneWidget);
      expect(find.text('Book Trial (₹0)'), findsWidgets);
      await tester.tap(find.text('3 Months'));
      await tester.pumpAndSettle();
      expect(find.text('Positioning & Network Leverage'), findsOneWidget);
    });

    testWidgets('the trial button asks for a session and checks the form before sending', (tester) async {
      final controller = await pump(tester);
      await tester.tap(find.text('Book Trial (₹0)'));
      await tester.pumpAndSettle();
      expect(find.text('What do you want to discuss?'), findsOneWidget);

      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(find.textContaining('at least 20 characters'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'I want to move from aerospace into cloud logistics.');
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(find.text('What do you want to discuss?'), findsNothing);
      expect(controller.offerings.firstWhere((o) => o.id == 'demo-discovery').myOpenRequestId, isNotNull);
      expect(find.text('Trial Requested'), findsWidgets);
    });

    testWidgets('Send Message on a profile with no pairing opens the mentoring request', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Send Message'));
      await tester.pumpAndSettle();
      expect(find.text('Ask Srikanth to mentor you'), findsOneWidget);
    });

    testWidgets('the route helper builds the screen on the API source and shows a failure', (tester) async {
      final api = _Api({});
      await tester.pumpWidget(
        Provider<ApiClient>.value(
          value: _client(api),
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Builder(builder: (context) => mentorProfileRoute(context, 'nobody')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load this mentor"), findsOneWidget);
      expect(api.calls, contains('GET /mentorship/mentors/nobody'));
    });

    Future<MentorProfileController> pumpApi(
      WidgetTester tester,
      Map<String, Object Function(RequestOptions)> routes, {
      ProfileTab tab = ProfileTab.overview,
      VoidCallback? onBack,
      _Api? api,
      MentorProfileNavigation? navigation,
    }) async {
      tester.view.physicalSize = const Size(780, 4600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final controller = MentorProfileController(
        repository: ApiMentorProfileRepository(api: _client(api ?? _Api(routes))),
        mentorId: 'm1',
        navigation: navigation ?? const MentorProfileNavigation(),
      );
      await tester.runAsync(controller.load);
      controller.selectTab(tab);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(
            value: controller,
            child: MentorProfileScreen(mentorId: 'm1', onBack: onBack ?? () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('Back leaves the page, the bell opens notifications, Verified Mentor says what it means', (
      tester,
    ) async {
      final urls = _launches(tester);
      final hops = _Hops();
      var back = 0;
      await pumpApi(
        tester,
        _routes(profile: _plainProfile()),
        onBack: () => back++,
        navigation: hops.navigation,
      );
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pump();
      expect(back, 1);

      // The bell opens the app's notifications, never the website's page.
      await tester.tap(find.byIcon(LucideIcons.bell));
      await tester.pumpAndSettle();
      expect(hops.events, ['notifications']);
      expect(urls, isEmpty);

      await tester.tap(find.text('Verified Mentor'));
      await tester.pump();
      expect(find.text("Verified Mentor: ICR has reviewed and approved Srikanth's mentor profile."), findsOneWidget);
    });

    testWidgets('Verified Mentor is drawn only for a profile ICR approved', (tester) async {
      await pumpApi(tester, _routes(profile: _plainProfile({'status': 'PENDING'})));
      expect(find.text('Verified Mentor'), findsNothing);
    });

    testWidgets('the route helper: Back pops the profile', (tester) async {
      await tester.pumpWidget(
        Provider<ApiClient>.value(
          value: _client(_Api(_routes(profile: _plainProfile()))),
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      Navigator.push(context, MaterialPageRoute<void>(builder: (c) => mentorProfileRoute(c, 'm1'))),
                  child: const Text('open the mentor'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open the mentor'));
      await tester.pumpAndSettle();
      expect(find.byType(MentorProfileScreen), findsOneWidget);
      expect(find.text('Srikanth Sriramagiri'), findsOneWidget);
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(MentorProfileScreen), findsNothing);
      expect(find.text('open the mentor'), findsOneWidget);
    });

    testWidgets('the three tabs show their own content', (tester) async {
      await pumpApi(tester, _routes(profile: _plainProfile()));
      expect(find.text('About Srikanth'), findsOneWidget);
      expect(find.text('Career Journey'), findsOneWidget);

      await tester.tap(find.text('Offerings'));
      await tester.pumpAndSettle();
      expect(find.text('About Srikanth'), findsNothing);
      expect(find.textContaining('Tap any offering to inspect'), findsOneWidget);
      for (final chip in ['All', '1:1 Mentorship', 'Group Sessions', 'Resources']) {
        expect(find.text(chip), findsOneWidget);
      }

      await tester.tap(find.text('Recommendations'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tap any offering to inspect'), findsNothing);
      // Both reviews (a named testimonial and a written one), and the way to the rest.
      expect(find.text('Dev Mangtani'), findsOneWidget);
      expect(find.text('A mentee'), findsOneWidget);
      expect(find.text('View all 42 verified reviews'), findsOneWidget);

      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();
      expect(find.text('About Srikanth'), findsOneWidget);
    });

    testWidgets('the offering filters narrow the rows and one with nothing behind it says so', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Offerings'));
      await tester.pumpAndSettle();
      expect(find.text('Purchase Guide'), findsNWidgets(3));

      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();
      expect(find.text('Book Now'), findsNothing);
      expect(find.text('Purchase Guide'), findsNWidgets(3));
      expect(find.text('Ask Query'), findsOneWidget);

      await tester.tap(find.text('1:1 Mentorship'));
      await tester.pumpAndSettle();
      expect(find.text('Purchase Guide'), findsNothing);
      expect(find.text('Book Now'), findsNWidgets(2));

      await tester.tap(find.text('Group Sessions'));
      await tester.pumpAndSettle();
      expect(find.textContaining('has not listed anything under this filter'), findsOneWidget);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('Book Now'), findsNWidgets(2));
    });

    testWidgets('...read more unfolds the bio', (tester) async {
      await pump(tester);
      expect(find.text('...read more'), findsOneWidget);
      expect(find.textContaining('building the supplier base behind it.'), findsNothing);
      await tester.tap(find.text('...read more'));
      await tester.pumpAndSettle();
      expect(find.text('...read more'), findsNothing);
      expect(find.textContaining('building the supplier base behind it.'), findsOneWidget);
    });

    testWidgets('View all verified reviews opens the Recommendations tab in the app, not the website', (tester) async {
      final urls = _launches(tester);
      await pump(tester);
      expect(find.text('...read more'), findsOneWidget, reason: 'the Overview tab shows the About section');
      await tester.ensureVisible(find.text('View all 42 verified reviews'));
      await tester.tap(find.text('View all 42 verified reviews'));
      await tester.pumpAndSettle();
      expect(urls, isEmpty);
      expect(find.text('...read more'), findsNothing, reason: 'the Recommendations tab has replaced the Overview');
    });

    testWidgets('the pinned bar and the hero ask the same thing', (tester) async {
      await pump(tester);
      // The design: "Book Trial (₹0)" in the hero, "Book Free Trial" on the bar, a chat glyph beside it.
      expect(find.text('Book Trial (₹0)'), findsOneWidget);
      expect(find.text('Book Free Trial'), findsOneWidget);
      await tester.tap(find.text('Book Free Trial'));
      await tester.pumpAndSettle();
      expect(find.text('What do you want to discuss?'), findsOneWidget);
    });

    testWidgets('the chat glyph on the bar opens the same ask as Send Message', (tester) async {
      await pump(tester);
      await tester.tap(find.byIcon(LucideIcons.messageSquare).last);
      await tester.pumpAndSettle();
      expect(find.text('Ask Srikanth to mentor you'), findsOneWidget);
    });

    testWidgets('each offering button does its own job', (tester) async {
      final urls = _launches(tester);
      await pump(tester);
      await tester.tap(find.text('Offerings'));
      await tester.pumpAndSettle();

      // Book Now: a request for the session (the mentor sets the time), with its own form.
      await tester.tap(find.text('Book Now').at(1));
      await tester.pumpAndSettle();
      expect(find.text('Request Personal Interview & GD Preparation'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('What do you want to discuss?'), findsNothing);

      // Ask Query: the same kind of ask for a written consultation.
      await tester.tap(find.text('Ask Query'));
      await tester.pumpAndSettle();
      expect(find.text('Request Statement of Purpose (SOP) Review'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Purchase Guide (paid): the website, where payment runs.
      await tester.tap(find.text('Purchase Guide').first);
      await tester.pumpAndSettle();
      expect(urls, ['https://icr.org.in/mentorship/mentors/demo-srikanth']);

      // Apply for Pro Mentorship (paid plan): the website as well.
      urls.clear();
      await tester.ensureVisible(find.text('Apply for Pro Mentorship'));
      await tester.tap(find.text('Apply for Pro Mentorship'));
      await tester.pumpAndSettle();
      expect(urls, ['https://icr.org.in/mentorship/mentors/demo-srikanth']);
    });

    testWidgets('the preview link and the row open the sheet; its Plans button opens the plan; its button asks', (
      tester,
    ) async {
      final urls = _launches(tester);
      await pump(tester);
      await tester.tap(find.text('Offerings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inspect 4-week diagnostic preview'));
      await tester.pumpAndSettle();
      expect(find.text('Curriculum Roadmap'), findsOneWidget);
      expect(find.text('Plans'), findsOneWidget);

      // Plans: the ongoing plan's own sheet, with its own button.
      await tester.tap(find.text('Plans'));
      await tester.pumpAndSettle();
      expect(find.text('Curriculum Roadmap'), findsNothing);
      expect(find.text('Pro Mentorship Tier'), findsWidgets);
      expect(find.text('Plans'), findsNothing);
      await tester.tap(find.text('Subscribe'));
      await tester.pumpAndSettle();
      expect(urls, ['https://icr.org.in/mentorship/mentors/demo-srikanth']);
    });

    testWidgets("the sheet's Book Trial asks for the session", (tester) async {
      await pump(tester);
      await tester.tap(find.text('Offerings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('"What\'s going wrong?" Discovery Call'));
      await tester.pumpAndSettle();
      final inBar = find.descendant(of: find.byType(OfferingSheetBar), matching: find.text('Book Trial (₹0)'));
      expect(inBar, findsOneWidget);
      await tester.tap(inBar);
      await tester.pumpAndSettle();
      expect(find.text('What do you want to discuss?'), findsOneWidget);
    });

    testWidgets('a session form without a number on file asks for one, and sends it', (tester) async {
      final repo = _NoPhone();
      tester.view.physicalSize = const Size(780, 4600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final controller = MentorProfileController(repository: repo, mentorId: 'demo-srikanth');
      await tester.runAsync(controller.load);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(
            value: controller,
            child: MentorProfileScreen(mentorId: controller.mentorId, onBack: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Book Trial (₹0)'));
      await tester.pumpAndSettle();
      expect(find.text('Mobile number'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'I want to move from aerospace into cloud logistics.');
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(find.text('Add the mobile number the mentor can reach you on.'), findsOneWidget);
      expect(repo.sent, isEmpty);

      await tester.enterText(find.byType(TextField).at(2), '+919811111111');
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(repo.sent, ['+919811111111']);
      expect(find.text('Mobile number'), findsNothing);
    });

    testWidgets("an API that finds the number missing makes the form ask for it, then sends it", (tester) async {
      var attempts = 0;
      final routes = _routes(profile: _plainProfile())
        ..['POST /mentor-services/s1/request'] = ((o) {
          attempts++;
          final body = o.data as Map;
          return body['phone'] == null ? _phoneNeeded : {'id': 'pur1'};
        });
      final api = _Api(routes);
      await pumpApi(tester, routes, api: api);
      // The profile says a number is on file, so the form does not ask up front.
      await tester.tap(find.text('Book Trial (₹0)'));
      await tester.pumpAndSettle();
      expect(find.text('Mobile number'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'I want to move from aerospace into cloud logistics.');
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(attempts, 1);
      expect(find.text('Add a mobile number so your mentor can reach you.'), findsOneWidget);
      expect(find.text('Mobile number'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(2), '+919811111111');
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(api.bodies['POST /mentor-services/s1/request'], containsPair('phone', '+919811111111'));
      expect(find.text('Mobile number'), findsNothing);
    });

    testWidgets('the mentoring request: checks its length, asks for a number, sends, and says so', (tester) async {
      final routes = _routes(profile: _plainProfile())
        ..['GET /mentor-services/mentors/m1'] = ((_) => {'live': false, 'services': []})
        ..['GET /auth/me'] = ((_) => {
          'user': {'phone': null},
        })
        ..['POST /mentorship/requests'] = ((_) => {'id': 'req1'});
      final api = _Api(routes);
      final controller = await pumpApi(tester, routes, api: api);
      // No free session to book: the hero asks for mentoring itself.
      expect(find.text('Request Mentoring'), findsWidgets);
      await tester.tap(find.text('Send Message'));
      await tester.pumpAndSettle();
      expect(find.text('Ask Srikanth to mentor you'), findsOneWidget);
      expect(find.text('Mobile number'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Too short');
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(find.textContaining('at least 30 characters'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Please mentor me on moving into supply planning.');
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(find.text('Add the mobile number the mentor can reach you on.'), findsOneWidget);
      expect(api.calls, isNot(contains('POST /mentorship/requests')));

      await tester.enterText(find.byType(TextField).at(1), '+919811111111');
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(api.bodies['POST /mentorship/requests'], {
        'mentorProfileId': 'm1',
        'message': 'Please mentor me on moving into supply planning.',
        'phone': '+919811111111',
      });
      expect(find.text('Ask Srikanth to mentor you'), findsNothing);
      expect(find.textContaining('Request sent to Srikanth'), findsOneWidget);
      // Sent: the button waits for the mentor's answer.
      expect(controller.profile!.viewer!.blocker, AskBlocker.requestPending);
      expect(find.text('Request Pending'), findsWidgets);
    });

    testWidgets(
      "Send Message: a live pairing opens its thread; a blocked viewer reads the API's reason; the owner has none",
      (tester) async {
        final urls = _launches(tester);
        final hops = _Hops();
        // A live pairing.
        var routes = _routes(
          profile: _plainProfile({
            'viewer': {'isOwner': false, 'canRequest': false, 'blocker': 'ALREADY_MATCHED', 'mentorshipId': 'ms1'},
          }),
        )..['POST /mentorship/ms1/conversation'] = ((_) => {'conversationId': 'c9'});
        await pumpApi(tester, routes, navigation: hops.navigation);
        await tester.tap(find.text('Send Message'));
        await tester.pumpAndSettle();
        expect(hops.events, ['conversation:c9'], reason: 'the thread opens in the app');
        expect(urls, isEmpty);

        // Blocked: the sentence is the API's own.
        routes = _routes(
          profile: _plainProfile({
            'viewer': {
              'isOwner': false,
              'canRequest': false,
              'blocker': 'AT_CAPACITY',
              'blockedReason': 'Srikanth is at capacity right now.',
            },
          }),
        );
        await pumpApi(tester, routes);
        await tester.tap(find.text('Send Message'));
        await tester.pump();
        expect(find.text('Srikanth is at capacity right now.'), findsOneWidget);

        // The owner: no message button, and the main button edits their profile.
        urls.clear();
        hops.events.clear();
        routes = _routes(
          profile: _plainProfile({
            'viewer': {'isOwner': true, 'canRequest': false},
          }),
        );
        await pumpApi(tester, routes, navigation: hops.navigation);
        expect(find.text('Send Message'), findsNothing);
        expect(find.text('Book Trial (₹0)'), findsNothing);
        await tester.tap(find.text('Edit My Profile').first);
        await tester.pumpAndSettle();
        expect(hops.events, ['editMentorProfile']);
        expect(urls, isEmpty);
      },
    );

    testWidgets('with no free session the main button follows where the viewer stands', (tester) async {
      Map<String, Object Function(RequestOptions)> routes(Map<String, Object?> viewer) =>
          _routes(profile: _plainProfile({'viewer': viewer}))
            ..['GET /mentor-services/mentors/m1'] = ((_) => {'live': false, 'services': []});
      final urls = _launches(tester);
      final hops = _Hops();

      // [opens] is a page of the website; [hop] is where the app itself goes.
      Future<void> expectLabel(Map<String, Object?> viewer, String label, {String? opens, String? hop}) async {
        urls.clear();
        hops.events.clear();
        await pumpApi(tester, routes(viewer), navigation: hops.navigation);
        expect(find.text(label), findsWidgets, reason: label);
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
        expect(urls, opens == null ? isEmpty : ['https://icr.org.in$opens'], reason: label);
        expect(hops.events, hop == null ? isEmpty : [hop], reason: label);
      }

      await expectLabel({'canRequest': false, 'mentorshipId': 'ms1'}, 'Open Our Mentorship', hop: 'pairing:ms1');
      await expectLabel({'canRequest': false, 'pendingRequestId': 'r1'}, 'Request Pending');
      await expectLabel({'canRequest': false, 'blocker': 'AT_CAPACITY'}, 'At Capacity');
      await expectLabel({'canRequest': false, 'blocker': 'PLAN_LIMIT'}, 'See Plans', opens: '/career/plans');
      // No mentee profile yet: the goals are written in the app (My mentoring, Goals), not on the website.
      await expectLabel(
        {'canRequest': false, 'blocker': 'NO_MENTEE_PROFILE'},
        'Tell Us Your Goals First',
        hop: 'goals',
      );
    });

    testWidgets('a free guide is taken in the app; a refusal is shown, not hidden', (tester) async {
      final routes = _routes(profile: _plainProfile())
        ..['GET /mentor-services/mentors/m1'] = ((_) => {
          'live': true,
          'services': [
            {'id': 'free1', 'type': 'RESOURCE', 'title': 'Checklist', 'pricePaisa': 0, 'fileName': 'checklist.pdf'},
            {'id': 'paid1', 'type': 'RESOURCE', 'title': 'Handbook', 'pricePaisa': 900, 'fileName': 'handbook.pdf'},
          ],
        })
        ..['POST /mentor-services/free1/checkout'] = ((_) => {'devActivated': true, 'purchaseId': 'p1'});
      final urls = _launches(tester);
      final api = _Api(routes);
      await pumpApi(tester, routes, tab: ProfileTab.offerings, api: api);
      await tester.tap(find.text('Get Guide'));
      await tester.pumpAndSettle();
      expect(api.bodies['POST /mentor-services/free1/checkout'], isEmpty);
      expect(find.textContaining('Added to your purchases'), findsOneWidget);
      expect(urls, isEmpty);

      // A paid guide never touches the checkout API: it opens that service's checkout on the website.
      await tester.tap(find.text('Purchase Guide'));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('POST /mentor-services/paid1/checkout')));
      expect(urls, ['https://icr.org.in/mentorship/mentors/m1?book=paid1']);

      // A refusal: the API's sentence, and nothing claims success.
      final refusing = _routes(profile: _plainProfile())
        ..['GET /mentor-services/mentors/m1'] = routes['GET /mentor-services/mentors/m1']!
        ..['POST /mentor-services/free1/checkout'] = ((_) => (400, '{"message":"You cannot buy your own service."}'));
      await pumpApi(tester, refusing, tab: ProfileTab.offerings);
      await tester.tap(find.text('Get Guide'));
      await tester.pumpAndSettle();
      expect(find.text('You cannot buy your own service.'), findsOneWidget);
      expect(find.textContaining('Added to your purchases'), findsNothing);
    });

    testWidgets('a programme: Book Now sends the request; asking again goes to the website instead', (tester) async {
      final urls = _launches(tester);
      final hops = _Hops();
      final routes = _routes(profile: _plainProfile())
        ..['POST /mentor-plans/pl2/request'] = ((_) => {
          'ok': true,
          'subscriptionId': 'sub1',
          'status': 'PENDING_MENTOR',
        });
      final api = _Api(routes);
      final controller = await pumpApi(
        tester,
        routes,
        tab: ProfileTab.offerings,
        api: api,
        navigation: hops.navigation,
      );
      expect(find.text('Inspect 2-session syllabus preview'), findsOneWidget);
      await tester.tap(find.text('Book Now').first);
      await tester.pumpAndSettle();
      expect(api.calls.where((c) => c == 'POST /mentor-plans/pl2/request'), hasLength(1));
      expect(find.textContaining('Request sent. Once Srikanth accepts'), findsOneWidget);
      expect(controller.offerings.firstWhere((o) => o.id == 'pl2').myOpenRequestId, isNotNull);
      expect(find.text('Requested'), findsOneWidget);

      // Requested: the row does not ask a second time, it follows the request up in My mentoring's Purchases.
      await tester.tap(find.text('Requested'));
      await tester.pumpAndSettle();
      expect(api.calls.where((c) => c == 'POST /mentor-plans/pl2/request'), hasLength(1));
      expect(hops.events, ['purchases']);
      expect(urls, isEmpty);
    });

    testWidgets('a programme asked for with no number: the sheet asks for it, then sends it', (tester) async {
      final routes = _routes(profile: _plainProfile())
        ..['GET /auth/me'] = ((_) => {
          'user': {'phone': null},
        })
        ..['POST /mentor-plans/pl2/request'] = ((_) => {
          'ok': true,
          'subscriptionId': 'sub1',
          'status': 'PENDING_MENTOR',
        });
      final api = _Api(routes);
      await pumpApi(tester, routes, tab: ProfileTab.offerings, api: api);
      await tester.tap(find.text('Book Now').first);
      await tester.pumpAndSettle();
      expect(find.text('Add your mobile number'), findsOneWidget);
      expect(api.calls, isNot(contains('POST /mentor-plans/pl2/request')));

      await tester.enterText(find.byType(TextField).first, '+919811111111');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(api.bodies['POST /mentor-plans/pl2/request'], {'phone': '+919811111111'});
    });

    testWidgets('pull to refresh reads the profile again', (tester) async {
      final api = _Api(_routes(profile: _plainProfile()));
      await pumpApi(tester, const {}, api: api);
      expect(api.calls.where((c) => c == 'GET /mentorship/mentors/m1'), hasLength(1));
      // A phone-sized window: the pull must travel a quarter of the screen to arm the indicator.
      tester.view.physicalSize = const Size(780, 1600);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(api.calls.where((c) => c == 'GET /mentorship/mentors/m1'), hasLength(2));
      // The page stays up while it reloads.
      expect(find.text('Srikanth Sriramagiri'), findsOneWidget);
    });

    testWidgets('a profile that could not load offers Try again, and loads when it can', (tester) async {
      final routes = <String, Object Function(RequestOptions)>{};
      final api = _Api(routes);
      await pumpApi(tester, routes, api: api);
      expect(find.text("Couldn't load this mentor"), findsOneWidget);
      expect(find.text('Srikanth Sriramagiri'), findsNothing);

      routes.addAll(_routes(profile: _plainProfile()));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Srikanth Sriramagiri'), findsOneWidget);
      expect(find.text("Couldn't load this mentor"), findsNothing);
    });

    testWidgets("a group session's seat is reserved on the website, on that session's page", (tester) async {
      final urls = _launches(tester);
      await pumpApi(tester, _routes(profile: _plainProfile()), tab: ProfileTab.offerings);
      expect(find.text('Resume clinic'), findsOneWidget);
      await tester.tap(find.text('Reserve Seat'));
      await tester.pumpAndSettle();
      expect(urls, ['https://icr.org.in/mentorship/groups/g1']);
    });

    testWidgets('an open sheet closes when the page behind it is tapped', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Offerings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inspect 4-week diagnostic preview'));
      await tester.pumpAndSettle();
      expect(find.text('Curriculum Roadmap'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Curriculum Roadmap'), findsNothing);
    });
  });

  group('what the profile and its rows say', () {
    MentorProfile mentor({List<String> modes = const [], String? city}) => MentorProfile(
      id: 'm',
      userId: 'u',
      firstName: 'A',
      lastName: 'B',
      city: city,
      modes: modes,
      stats: const MentorStats(sessions: '1', mentees: '1'),
    );

    test('a mentor who meets in person and remotely is Hybrid; otherwise the modes read as they are', () {
      expect(mentor(city: 'Hyderabad', modes: const ['Video', 'In person']).placeLabel, 'Hyderabad (Hybrid)');
      expect(mentor(city: 'Pune', modes: const ['Phone', 'Video', 'In person']).placeLabel, 'Pune (Hybrid)');
      expect(mentor(city: 'Pune', modes: const ['In person']).placeLabel, 'Pune (In person)');
      expect(mentor(city: 'Pune', modes: const ['Video', 'Phone']).placeLabel, 'Pune (Video / Phone)');
      expect(mentor(modes: const ['Video']).placeLabel, 'Video');
      expect(mentor(city: 'Pune').placeLabel, 'Pune');
      expect(mentor().placeLabel, isNull);
    });

    test('the line under the name: role and headline, or the headline alone when it names the employer', () {
      String line(String? role, String? org, String? headline) => TextSpan(
        children: roleLineSpans(
          MentorProfile(
            id: 'm',
            userId: 'u',
            firstName: 'A',
            lastName: 'B',
            roleTitle: role,
            roleOrganisation: org,
            headline: headline,
            stats: const MentorStats(sessions: '1', mentees: '1'),
          ),
        ),
      ).toPlainText().replaceAll('\u00A0', ' ');

      // The design: the mentor's own headline carries the line, "Microsoft" in bold, nothing repeated.
      const own = 'Supply Chain Leader at Microsoft • Ex-Tata Aerospace • BITS Pilani';
      expect(line('APAC Lead, Azure Planning & Execution', 'Microsoft', own), own);
      final spans = roleLineSpans(
        MentorProfile(
          id: 'm',
          userId: 'u',
          firstName: 'A',
          lastName: 'B',
          roleTitle: 'APAC Lead',
          roleOrganisation: 'Microsoft',
          headline: own,
          stats: const MentorStats(sessions: '1', mentees: '1'),
        ),
      ).cast<TextSpan>();
      expect(spans.where((t) => t.style != null).single.text, 'Microsoft');
      // A headline that does not say where they work follows "title at organisation".
      expect(line('Head of FM', 'Infosys', 'Ex-Tata • IIT'), 'Head of FM at Infosys • Ex-Tata • IIT');
      expect(line('Head of FM', 'Infosys', null), 'Head of FM at Infosys');
      expect(line(null, null, 'Ex-Tata • IIT'), 'Ex-Tata • IIT');
    });

    test('labels: sessions, terms, the apply button, a syllabus step, a resource tag', () {
      expect(sessionsLabel(26), '26+');
      expect(sessionsLabel(10), '10+');
      expect(sessionsLabel(9), '9');
      expect(sessionsLabel(0), '0');
      expect(termLabel(1), '1 Month');
      expect(termLabel(3), '3 Months');
      expect(monthsSpan(1), 'Month 1');
      expect(monthsSpan(6), 'Months 1-6');
      expect(applyName('Pro Mentorship Tier'), 'Pro Mentorship');
      expect(applyName('Growth plan'), 'Growth');
      expect(applyName('Tier'), 'Tier');
      expect(stepLabel(0, 'Diagnose'), 'Session 1: Diagnose');
      expect(stepLabel(1, 'Week 2: Plan'), 'Week 2: Plan');
      expect(stepLabel(2, 'Module 3 - Review'), 'Module 3 - Review');
      expect(isPhoneRefusal('Add a mobile number so your mentor can reach you.'), isTrue);
      expect(isPhoneRefusal('You have already asked for this program.'), isFalse);
      expect(isPhoneRefusal(null), isFalse);

      expect(resourceTag('linkedin-niche-bible'), (label: 'Digital Guide', generic: true));
      expect(resourceTag(null), (label: 'Digital Guide', generic: true));
      expect(resourceTag('guide.pdf'), (label: 'PDF Guide', generic: false));
      expect(resourceTag('Templates.ZIP'), (label: 'Templates Pack', generic: false));
      expect(resourceTag('notes.xyz'), (label: 'XYZ File', generic: false));
      expect(resourceTag('Curated Prompts'), (label: 'Curated Prompts', generic: false));
      expect(resourceTag('PDF & Templates'), (label: 'PDF & Templates', generic: false));
      expect(resourceTag('a_very_long_slug_without_spaces_at_all'), (label: 'Digital Guide', generic: true));
    });

    test('a resource row says "Instant Download" only beside a tag that names nothing', () async {
      final routes = _routes();
      routes['GET /mentor-services/mentors/m1'] = (_) => {
        'live': true,
        'services': [
          {'id': 'a', 'type': 'RESOURCE', 'title': 'Slug', 'pricePaisa': 900, 'fileName': 'linkedin-niche-bible'},
          {'id': 'b', 'type': 'RESOURCE', 'title': 'Label', 'pricePaisa': 900, 'fileName': 'Curated Prompts'},
          {'id': 'c', 'type': 'RESOURCE', 'title': 'Free', 'pricePaisa': 0, 'fileName': 'checklist.pdf'},
        ],
      };
      final repo = ApiMentorProfileRepository(api: _client(_Api(routes)));
      final rows = {for (final o in await repo.offerings(await repo.profile('m1'))) o.id: o};
      expect(rows['a']!.tags.map((t) => t.label), ['Digital Guide', 'Instant Download']);
      expect(rows['a']!.tags.last.green, isTrue);
      expect(rows['b']!.tags.map((t) => t.label), ['Curated Prompts']);
      expect(rows['c']!.tags.map((t) => t.label), ['PDF Guide']);
      expect(rows['c']!.ctaLabel, 'Get Guide');
      expect(rows['a']!.ctaLabel, 'Purchase Guide');
    });

    test("a programme the viewer asked for stays 'Requested' after a reload", () async {
      final routes = _routes()
        ..['GET /mentor-plans/subscriptions/mine'] = ((_) => [
          {'id': 'sub1', 'planId': 'pl2', 'status': 'PENDING_MENTOR'},
          {'id': 'sub0', 'planId': 'pl1', 'status': 'CANCELLED'},
        ]);
      final repo = ApiMentorProfileRepository(api: _client(_Api(routes)));
      final rows = {for (final o in await repo.offerings(await repo.profile('m1'))) o.id: o};
      expect(rows['pl2']!.myOpenRequestId, 'sub1');
      expect(rows['pl1']!.myOpenRequestId, isNull);
    });
  });

  group('one programme in several terms', () {
    Map<String, Object Function(RequestOptions)> termRoutes() => _routes(profile: _plainProfile())
      ..['GET /mentor-plans/by-mentor/m1'] = ((_) => _termPlans())
      ..['POST /mentor-plans/p1m/request'] = ((_) => {
        'ok': true,
        'subscriptionId': 'sub1m',
        'status': 'PENDING_MENTOR',
      })
      ..['POST /mentor-plans/p3m/request'] = ((_) => {
        'ok': true,
        'subscriptionId': 'sub3m',
        'status': 'PENDING_MENTOR',
      });

    test('the terms are one row, shortest first, and the plan card is the ongoing plan', () async {
      final repo = ApiMentorProfileRepository(api: _client(_Api(termRoutes())));
      final c = MentorProfileController(repository: repo, mentorId: 'm1');
      await c.load();
      expect(c.rows.map((o) => o.id), ['p1m', 's1', 's2', 's3', 'group-g1']);
      expect(c.featuredPlan?.id, 'pro');
      final terms = c.variantsOf(c.offerings.firstWhere((o) => o.id == 'p6m'));
      expect(terms.map((o) => o.id), ['p1m', 'p3m', 'p6m']);
      expect(terms.map((o) => o.termMonths), [1, 3, 6]);
      // A row that is not a programme has no siblings.
      expect(c.variantsOf(c.offerings.firstWhere((o) => o.id == 's2')).map((o) => o.id), ['s2']);
      c.selectFilter(OfferingFilter.oneOnOne);
      expect(c.rows.map((o) => o.id), ['p1m', 's1']);
    });

    testWidgets('the sheet toggles between the terms; the roadmap, the price and the button follow', (tester) async {
      final api = _Api(termRoutes());
      final controller = MentorProfileController(
        repository: ApiMentorProfileRepository(api: _client(api)),
        mentorId: 'm1',
      );
      tester.view.physicalSize = const Size(780, 4600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.runAsync(controller.load);
      controller.selectTab(ProfileTab.offerings);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(
            value: controller,
            child: MentorProfileScreen(mentorId: 'm1', onBack: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // One row for the three terms, with the preview link.
      expect(find.text('Discovery'), findsOneWidget);
      expect(find.text('Inspect 2-session syllabus preview'), findsOneWidget);

      await tester.tap(find.text('Inspect 2-session syllabus preview'));
      await tester.pumpAndSettle();
      expect(find.text('Curriculum Roadmap'), findsOneWidget);
      for (final label in ['1 Month', '3 Months', '6 Months']) {
        expect(find.text(label), findsOneWidget);
      }
      // The page stays under the sheet and repeats some labels: the bar is looked at on its own.
      Finder inBar(String text) => find.descendant(of: find.byType(OfferingSheetBar), matching: find.text(text));
      // The first term: the design's trial.
      expect(inBar('Book Trial (₹0)'), findsOneWidget);
      expect(inBar('Trial: ₹0'), findsOneWidget);
      expect(find.text('Week 1: Diagnose'), findsOneWidget);
      expect(find.text('Month 1'), findsOneWidget);
      expect(inBar('Starts at '), findsOneWidget);
      expect(inBar('₹12,500'), findsOneWidget);

      await tester.tap(find.text('3 Months'));
      await tester.pumpAndSettle();
      expect(find.text('3-session syllabus'), findsOneWidget);
      expect(find.text('Session 3: Execute'), findsOneWidget);
      expect(find.text('Months 1-3'), findsOneWidget);
      expect(inBar('Book Trial (₹0)'), findsNothing);
      expect(inBar('Trial: ₹0'), findsNothing);
      expect(inBar('Price '), findsOneWidget);
      expect(inBar('₹14,999'), findsOneWidget);
      expect(inBar('Book Now'), findsOneWidget);

      // The button asks for the term on show, not the first one.
      await tester.tap(inBar('Book Now'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /mentor-plans/p3m/request'));
      expect(api.calls, isNot(contains('POST /mentor-plans/p1m/request')));
      expect(controller.offerings.firstWhere((o) => o.id == 'p3m').myOpenRequestId, isNotNull);
    });

    testWidgets('one term has no toggle', (tester) async {
      final routes = _routes(profile: _plainProfile());
      final controller = MentorProfileController(
        repository: ApiMentorProfileRepository(api: _client(_Api(routes))),
        mentorId: 'm1',
      );
      tester.view.physicalSize = const Size(780, 4600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.runAsync(controller.load);
      controller.selectTab(ProfileTab.offerings);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ChangeNotifierProvider.value(
            value: controller,
            child: MentorProfileScreen(mentorId: 'm1', onBack: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inspect 2-session syllabus preview'));
      await tester.pumpAndSettle();
      expect(find.text('Curriculum Roadmap'), findsOneWidget);
      expect(find.text('Session 1: Diagnose'), findsOneWidget);
      expect(find.text('1 Month'), findsNothing);
      expect(find.text('3 Months'), findsNothing);
    });
  });
}
