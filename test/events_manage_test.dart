import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/core/theme/app_theme.dart';
import 'package:icr_mobile/features/events/event_models.dart' show eventsNow;
import 'package:icr_mobile/features/events_manage/event_form_sheet.dart';
import 'package:icr_mobile/features/events_manage/events_manage_kit.dart';
import 'package:icr_mobile/features/events_manage/events_manage_models.dart';
import 'package:icr_mobile/features/events_manage/events_manage_repository.dart';
import 'package:icr_mobile/features/events_manage/events_manage_rules.dart';
import 'package:icr_mobile/features/events_manage/manage_event_screen.dart';
import 'package:icr_mobile/features/events_manage/manage_events_screen.dart';

import 'helpers/fonts.dart';

/// 13 Nov 2026, 06:00 UTC — the day the samples are dated round.
final _now = DateTime.utc(2026, 11, 13, 6);

/// The finance limit the approval engine starts with: ₹10,000.
const _approvalLimitPaisa = 1000000;

/// The day and time dialogs, answering from a queue.
class FakePickers extends EventPickers {
  FakePickers({this.days = const [], this.times = const []});

  final List<DateTime> days;
  final List<TimeOfDay> times;
  int _day = 0;
  int _time = 0;

  @override
  Future<DateTime?> pickDay(BuildContext context, {required DateTime initial, String? help}) async =>
      _day < days.length ? days[_day++] : null;

  @override
  Future<TimeOfDay?> pickTime(BuildContext context, {required TimeOfDay initial, String? help}) async =>
      _time < times.length ? times[_time++] : null;
}

/// The staff Events API in memory, answering and refusing as the real one does.
class FakeEventsRepository implements EventsManageRepository {
  FakeEventsRepository() {
    events_ = [
      ManagedEvent(
        id: 'e1',
        title: 'FM Leaders Summit',
        slug: 'fm-leaders-summit',
        kind: 'CONFERENCE',
        location: 'Taj Lands End, Mumbai',
        description: '<p>Two days of facility leadership.</p><h3>Agenda</h3><ul><li>Keynote</li><li>Panel</li></ul>',
        capacity: 200,
        pricePaisa: 150000,
        startsAt: DateTime.utc(2026, 12, 4, 4, 30),
        endsAt: DateTime.utc(2026, 12, 4, 11, 30),
        going: 42,
        waitlisted: 3,
        callForSpeakersUntil: DateTime.utc(2026, 11, 25, 12),
        createdAt: DateTime.utc(2026, 10, 1),
      ),
      ManagedEvent(
        id: 'e2',
        title: 'Energy Audits Webinar',
        slug: 'energy-audits-webinar',
        kind: 'WEBINAR',
        location: 'Online (Zoom)',
        startsAt: DateTime.utc(2026, 11, 20, 9, 30),
        going: 18,
        published: false,
        hostCompany: const OrgRef(id: 'co-9', name: 'GreenGrid Services'),
        createdAt: DateTime.utc(2026, 10, 12),
      ),
      ManagedEvent(
        id: 'e3',
        title: 'Bengaluru Chapter Meetup',
        slug: 'bengaluru-chapter-meetup',
        kind: 'CHAPTER_MEET',
        location: 'ICR Bengaluru',
        startsAt: DateTime.utc(2026, 10, 10, 12),
        endsAt: DateTime.utc(2026, 10, 10, 14),
        going: 25,
        chapter: const OrgRef(id: 'ch-1', name: 'Bengaluru Chapter'),
        createdAt: DateTime.utc(2026, 9, 1),
      ),
    ];
    invitesBy = {
      'e1': [const EventInvite(id: 'i1', userId: 'u1', name: 'Asha Menon', email: 'asha@acme.com')],
      'e3': [
        const EventInvite(id: 'i7', userId: 'u7', name: 'Ravi Iyer', email: 'ravi@acme.com'),
        const EventInvite(id: 'i8', userId: 'u8', name: 'Meera Shah', email: 'meera@acme.com', source: 'TIER:GOLD'),
      ],
    };
    proposals = [
      const EventProposal(
        id: 'p1',
        title: 'Digital twins in practice',
        abstract: 'What a year of running a digital twin taught our estates team.',
        status: 'PENDING',
        speaker: 'Dev Rao',
        email: 'dev@estates.in',
        bio: 'Head of Estates',
      ),
      const EventProposal(
        id: 'p2',
        title: 'Net-zero retrofits',
        abstract: 'Three retrofits, costed.',
        status: 'PENDING',
        speaker: 'Nina Paul',
        email: 'nina@retro.in',
      ),
    ];
    packages = [
      const SponsorPackage(id: 'k1', name: 'Silver partner', pricePaisa: 2500000, benefits: ['Logo on the page']),
    ];
    sponsorships = [
      const SponsorshipRequest(
        id: 's1',
        status: 'REQUESTED',
        company: 'Acme FM',
        package: 'Silver partner',
        contact: 'Sam Rao',
        email: 'sam@acme.com',
        note: 'Happy to take a booth too.',
      ),
    ];
    tickets_ = [
      const TicketRow(
        id: 't1',
        status: 'PAID',
        totalPaisa: 177000,
        userId: 'u2',
        name: 'Kiran Das',
        firstName: 'Kiran',
        email: 'kiran@corp.in',
        couponCode: 'EARLY10',
      ),
      const TicketRow(
        id: 't2',
        status: 'PAID',
        totalPaisa: 1500000,
        userId: 'u3',
        name: 'Lata Bose',
        firstName: 'Lata',
        email: 'lata@corp.in',
      ),
    ];
    hosts = [
      _host('h1', 'PENDING', 'GreenGrid Services'),
      _host('h2', 'PENDING', 'Skyline Facilities'),
      _host('h3', 'APPROVED', 'Urban Estates'),
    ];
  }

  static HostApplication _host(String id, String status, String company) => HostApplication(
    id: id,
    status: status,
    company: company,
    about: 'We run quarterly round tables for facility heads across our client sites.',
    eventKinds: const ['ROUNDTABLE', 'WEBINAR'],
    frequency: 'Quarterly',
    website: 'https://example.com',
    contactName: 'Priya Nair',
    contactEmail: 'priya@example.com',
    appliedBy: 'Priya Nair',
    createdAt: DateTime.utc(2026, 11, 2),
    hostedEventCount: status == 'APPROVED' ? 2 : 0,
  );

  late List<ManagedEvent> events_;
  late Map<String, List<EventInvite>> invitesBy;
  late List<EventProposal> proposals;
  late List<SponsorPackage> packages;
  late List<SponsorshipRequest> sponsorships;
  late List<TicketRow> tickets_;
  late List<HostApplication> hosts;

  /// ICR members an invite by email finds.
  final members = {'zoya@acme.com': ('u20', 'Zoya Khan')};

  final List<EventsQuery> queries = [];
  final List<Map<String, Object?>> created = [];
  final List<(String, Map<String, Object?>)> updated = [];
  final List<String> deleted = [];
  final List<List<String>> invitedEmails = [];
  final List<String> tierSweeps = [];
  final List<(String, String, String?)> proposalDecisions = [];
  final List<(String, String, String?)> sponsorshipDecisions = [];
  final List<Map<String, Object?>> packageBodies = [];
  final List<(String, String?)> refunds = [];
  final List<List<String>> attendance = [];
  final List<(String, String, String?)> hostDecisions = [];

  @override
  Future<Paged<ManagedEvent>> events(EventsQuery query) async {
    queries.add(query);
    final q = query.search.trim().toLowerCase();
    final found = events_.where((e) {
      if (q.isNotEmpty &&
          !e.title.toLowerCase().contains(q) &&
          !(e.location ?? '').toLowerCase().contains(q) &&
          !(e.host ?? '').toLowerCase().contains(q)) {
        return false;
      }
      if (query.when == 'upcoming' && e.startsAt.isBefore(_now)) return false;
      if (query.when == 'past' && !e.startsAt.isBefore(_now)) return false;
      if (query.kind != null && e.kind != query.kind) return false;
      if (query.host == 'icr' && e.hostCompany != null) return false;
      if (query.host == 'partner' && e.hostCompany == null) return false;
      return true;
    }).toList();
    final start = (query.page - 1) * query.limit;
    return Paged(found.skip(start).take(query.limit).toList(), found.length);
  }

  @override
  Future<ManagedEvent?> event(String id) async => events_.where((e) => e.id == id).firstOrNull;

  @override
  Future<String> createEvent(Map<String, Object?> body) async {
    if (body['slug'] == 'taken') throw ApiError('An event already uses this address.', statusCode: 409);
    created.add(body);
    final id = 'new-${created.length}';
    events_ = [
      ManagedEvent(
        id: id,
        title: body['title'] as String,
        slug: body['slug'] as String?,
        kind: body['kind'] as String,
        startsAt: DateTime.parse(body['startsAt'] as String),
        capacity: body['capacity'] as int?,
        pricePaisa: (body['priceAmount'] as int?) ?? 0,
        published: body['published'] == true,
      ),
      ...events_,
    ];
    return id;
  }

  @override
  Future<void> updateEvent(String id, Map<String, Object?> body) async {
    updated.add((id, body));
    events_ = [
      for (final e in events_)
        if (e.id != id)
          e
        else
          ManagedEvent(
            id: e.id,
            title: body['title'] as String,
            slug: e.slug,
            kind: body['kind'] as String,
            description: body['description'] as String?,
            location: body['location'] as String?,
            capacity: body['capacity'] as int?,
            pricePaisa: (body['priceAmount'] as int?) ?? 0,
            startsAt: DateTime.parse(body['startsAt'] as String),
            endsAt: body['endsAt'] == null ? null : DateTime.parse(body['endsAt'] as String),
            going: e.going,
            waitlisted: e.waitlisted,
            published: body['published'] == true,
            inviteOnly: body['inviteOnly'] == true,
            createdAt: e.createdAt,
          ),
    ];
  }

  @override
  Future<void> deleteEvent(String id) async {
    deleted.add(id);
    events_ = events_.where((e) => e.id != id).toList();
  }

  @override
  Future<List<OrgRef>> chapters() async => const [OrgRef(id: 'ch-1', name: 'Bengaluru Chapter')];

  @override
  Future<List<OrgRef>> councils() async => const [OrgRef(id: 'cn-1', name: 'Healthcare Council')];

  @override
  Future<List<String>> addresses(String query, {String? session}) async => [
    'Taj Lands End, Bandra West, Mumbai',
    'Taj Mahal Palace, Colaba, Mumbai',
  ];

  @override
  Future<EventProgramme> programme(String eventId) async => EventProgramme(
    invites: invitesBy[eventId] ?? const [],
    proposals: eventId == 'e1' ? proposals : const [],
    sponsorships: eventId == 'e1' ? sponsorships : const [],
    packages: eventId == 'e1' ? packages : const [],
  );

  @override
  Future<InviteResult> invite(String eventId, {List<String> emails = const [], List<String> userIds = const []}) async {
    invitedEmails.add(emails);
    final unknown = <String>[];
    var invited = 0;
    for (final e in emails) {
      final member = members[e.toLowerCase()];
      if (member == null) {
        unknown.add(e);
        continue;
      }
      invited += 1;
      invitesBy[eventId] = [
        EventInvite(id: 'i-${member.$1}', userId: member.$1, name: member.$2, email: e),
        ...invitesBy[eventId] ?? const [],
      ];
    }
    return InviteResult(invited: invited, unknown: unknown);
  }

  @override
  Future<TierInviteResult> inviteByTier(String eventId, String tier) async {
    tierSweeps.add(tier);
    return const TierInviteResult(invited: 3, considered: 40);
  }

  @override
  Future<void> removeInvite(String eventId, String userId) async {
    invitesBy[eventId] = (invitesBy[eventId] ?? const []).where((i) => i.userId != userId).toList();
  }

  @override
  Future<void> decideProposal(String proposalId, {required String status, String? note}) async {
    if (status == 'DECLINED' && (note ?? '').trim().isEmpty) {
      throw ApiError("Say why you're declining. They are told the reason.", statusCode: 400);
    }
    proposalDecisions.add((proposalId, status, note));
    proposals = [
      for (final p in proposals)
        if (p.id != proposalId)
          p
        else
          EventProposal(
            id: p.id,
            title: p.title,
            abstract: p.abstract,
            status: status,
            speaker: p.speaker,
            email: p.email,
            bio: p.bio,
            reviewNote: note,
          ),
    ];
  }

  @override
  Future<void> createPackage(String eventId, Map<String, Object?> body) async {
    packageBodies.add(body);
    packages = [
      ...packages,
      SponsorPackage(
        id: 'k${packages.length + 1}',
        name: body['name'] as String,
        pricePaisa: body['priceAmount'] as int,
        benefits: (body['benefits'] as List).cast<String>(),
        slots: body['slots'] as int?,
      ),
    ];
  }

  @override
  Future<void> updatePackage(String packageId, Map<String, Object?> body) async {
    packageBodies.add({...body, 'id': packageId});
  }

  @override
  Future<void> deletePackage(String packageId) async {
    packages = packages.where((p) => p.id != packageId).toList();
  }

  @override
  Future<void> decideSponsorship(String sponsorshipId, {required String status, String? note}) async {
    sponsorshipDecisions.add((sponsorshipId, status, note));
    sponsorships = [
      for (final s in sponsorships)
        if (s.id != sponsorshipId)
          s
        else
          SponsorshipRequest(
            id: s.id,
            status: status,
            company: s.company,
            package: s.package,
            contact: s.contact,
            email: s.email,
            note: s.note,
            decisionNote: note,
          ),
    ];
  }

  @override
  Future<Paged<TicketRow>> tickets(String eventId, {int page = 1}) async =>
      eventId == 'e1' && page == 1 ? Paged(tickets_, tickets_.length) : const Paged([], 0);

  @override
  Future<RefundOutcome> refundTicket(String ticketId, {String? refundRef}) async {
    final t = tickets_.firstWhere((t) => t.id == ticketId);
    final ref = (refundRef ?? '').trim();
    refunds.add((ticketId, ref.isEmpty ? null : ref));
    // Above the finance limit nothing is recorded: the request waits for a second approver.
    if (t.totalPaisa > _approvalLimitPaisa) {
      return RefundOutcome.fromJson({
        'approvalRequired': true,
        'approval': {'id': 'ap-1', 'amountPaisa': t.totalPaisa, 'status': 'PENDING'},
      });
    }
    if (ref.isEmpty) {
      throw ApiError('Add the gateway, bank or UPI reference of the money sent.', statusCode: 400);
    }
    tickets_ = [
      for (final row in tickets_)
        if (row.id != ticketId)
          row
        else
          TicketRow(
            id: row.id,
            status: 'REFUNDED',
            totalPaisa: row.totalPaisa,
            userId: row.userId,
            name: row.name,
            firstName: row.firstName,
            email: row.email,
            refundRef: ref,
          ),
    ];
    return RefundOutcome.fromJson({'refunded': true, 'refundRef': ref});
  }

  @override
  Future<AttendanceResult> markAttendance(String eventId, List<String> userIds) async {
    attendance.add(userIds);
    // Only people who had a place can have attended: u8 never took one.
    return AttendanceResult(marked: userIds.where((u) => u != 'u8').length, hoursEach: 2);
  }

  @override
  Future<Paged<HostApplication>> hostApplications({
    String? status,
    String search = '',
    int page = 1,
    int limit = 20,
  }) async {
    final q = search.trim().toLowerCase();
    final found = hosts
        .where((h) => (status == null || h.status == status) && (q.isEmpty || h.company.toLowerCase().contains(q)))
        .toList();
    return Paged(found.skip((page - 1) * limit).take(limit).toList(), found.length);
  }

  @override
  Future<int> pendingHostApplications() async => hosts.where((h) => h.status == 'PENDING').length;

  @override
  Future<HostApplication> decideHostApplication(String id, String action, {String? note}) async {
    if (action != 'approve' && (note ?? '').trim().isEmpty) {
      throw ApiError('Give the company a reason.', statusCode: 400);
    }
    hostDecisions.add((id, action, note));
    final to = switch (action) {
      'approve' => 'APPROVED',
      'reject' => 'REJECTED',
      _ => 'REVOKED',
    };
    late HostApplication changed;
    hosts = [
      for (final h in hosts)
        if (h.id != id) h else changed = _host(h.id, to, h.company),
    ];
    return changed;
  }
}

/// Manage Events — the staff Events console of the website (`/admin/community?tab=events` and `?tab=event-hosts`),
/// native: the list and its search, the event form's rules, one event's guest list, speakers, sponsors, tickets
/// and attendance, and the companies asking to host.
void main() {
  setUpAll(loadAppFonts);

  late FakeEventsRepository repo;

  setUp(() {
    repo = FakeEventsRepository();
    eventsNow = () => _now;
  });

  tearDown(() => eventsNow = DateTime.now);

  void useScreen(WidgetTester tester, {double width = 390, double height = 844}) {
    tester.view.physicalSize = Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  /// The wrapper the app passes: something drawn under every pushed page (its bottom bar).
  Widget wrap(Widget page) => Column(
    children: [
      Expanded(child: page),
      const Material(
        child: SizedBox(key: Key('bottom-bar'), height: 56, width: double.infinity),
      ),
    ],
  );

  Future<void> pumpConsole(
    WidgetTester tester, {
    String? initialTab,
    String? focus,
    EventPickers pickers = const EventPickers(),
    double width = 390,
    double height = 844,
  }) async {
    useScreen(tester, width: width, height: height);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ManageEventsScreen(
          repository: repo,
          onBack: () {},
          initialTab: initialTab,
          focusHostApplicationId: focus,
          pageWrap: wrap,
          pickers: pickers,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpEvent(
    WidgetTester tester,
    String id, {
    EventPickers pickers = const EventPickers(),
    VoidCallback? onBack,
    double width = 390,
    double height = 844,
  }) async {
    useScreen(tester, width: width, height: height);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ManageEventScreen(repository: repo, eventId: id, onBack: onBack ?? () {}, pickers: pickers),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapOn(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    final field = find.byKey(Key(key));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, text);
    await tester.pumpAndSettle();
  }

  /// A select field's own tap target (a set value adds a clear button, which is an InkWell too).
  Finder selectField(String key) => find.descendant(of: find.byKey(Key(key)), matching: find.byType(InkWell)).first;

  Future<void> openTab(WidgetTester tester, int index) => tapOn(tester, find.byKey(ValueKey('event-tab-$index')));

  Future<void> save(WidgetTester tester) => tapOn(tester, find.byKey(const Key('sheet.save')));

  /// Lets the search box's 250 ms pause pass.
  Future<void> search(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(Key(key)), text);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  group('the rules', () {
    test('a description is split into the form’s fields and built back as the page reads it', () {
      const html =
          '<p>Two days of facility leadership.</p>\n<h3>Agenda</h3>\n<ul>\n<li>Keynote</li>\n<li>Panel</li>\n</ul>'
          '\n<h3>Sponsors</h3>\n<p>Thanks to Acme.</p>';
      final parsed = parseAbout(html);
      expect(parsed.values['overview'], 'Two days of facility leadership.');
      expect(parsed.values['agenda'], 'Keynote\nPanel');
      expect(parsed.values['audience'], '');
      // A heading no field covers is kept as stored.
      expect(parsed.extra, '<h3>Sponsors</h3>\n<p>Thanks to Acme.</p>');
      expect(composeAbout(parsed.values, extra: parsed.extra), html);
      expect(composeAbout({'overview': '', 'agenda': ''}), '');
      expect(
        composeAbout({'agenda': '- 10:00 — Coffee\n• 11:00 — Talks'}),
        '<h3>Agenda</h3>\n<ul>\n<li>10:00 — Coffee</li>\n<li>11:00 — Talks</li>\n</ul>',
      );
      expect(composeAbout({'overview': 'A & B <ok>'}), '<p>A &amp; B &lt;ok&gt;</p>');
    });

    test('the form writes times on the Indian clock, the one the Events screens read', () {
      final at = istWallToUtc(2026, 12, 4, 10, 0);
      expect(at, DateTime.utc(2026, 12, 4, 4, 30));
      expect(dayTimeLabel(at), '4 Dec 2026, 10:00 AM IST');
      expect(longDayLabel(at), 'Friday, 4 December 2026');
      expect(slugify('FM Leaders Summit — 2026!'), 'fm-leaders-summit-2026');
    });

    test('an event is held to the API’s limits before it is sent', () {
      final draft = EventDraft();
      expect(draft.problems().keys, containsAll(['title', 'startsAt']));
      draft
        ..title = 'x' * 161
        ..capacity = '0'
        ..price = '1000001'
        ..location = 'y' * 241
        ..startsAt = DateTime.utc(2026, 12, 4, 10)
        ..endsAt = DateTime.utc(2026, 12, 4, 9);
      expect(draft.problems().keys, containsAll(['title', 'capacity', 'price', 'location', 'endsAt']));
      draft
        ..title = 'Summit'
        ..capacity = '2.5'
        ..price = '-1'
        ..location = ''
        ..endsAt = null;
      expect(draft.problems().keys, unorderedEquals(['capacity', 'price']));
      draft
        ..capacity = ''
        ..price = '1499.50';
      expect(draft.problems(), isEmpty);
      final body = draft.toJson(create: true);
      expect(body['priceAmount'], 149950);
      expect(body.containsKey('capacity'), isFalse);
      expect(body.containsKey('endsAt'), isFalse);
      // Editing, a cleared field is sent as null so the API clears it.
      final patch = draft.toJson(create: false);
      expect(patch.containsKey('capacity'), isTrue);
      expect(patch['capacity'], isNull);
      expect(patch['chapterId'], isNull);
      expect(patch['location'], isNull);
    });

    test('a package, an invite and a refund reference are held to their limits', () {
      expect(PackageDraft().problems().keys, containsAll(['name', 'price']));
      final package = PackageDraft(name: 'Gold', price: '50000', slots: '0', benefits: List.filled(21, 'b').join('\n'));
      expect(package.problems().keys, unorderedEquals(['slots', 'benefits']));
      package
        ..slots = ''
        ..benefits = 'Logo\n\nBooth ';
      expect(package.problems(), isEmpty);
      expect(package.toJson(), {
        'name': 'Gold',
        'priceAmount': 5000000,
        'benefits': ['Logo', 'Booth'],
        'slots': null,
      });

      expect(splitEmails('a@x.com, b@y.com;c@z.in\n'), ['a@x.com', 'b@y.com', 'c@z.in']);
      expect(inviteEmailsProblem(['a@x.com']), isNull);
      expect(inviteEmailsProblem(['a@x.com', 'nope']), 'nope is not an email address.');
      expect(inviteEmailsProblem([]), isNotNull);

      expect(refundRefProblem(''), isNull);
      expect(refundRefProblem('ab'), isNotNull);
      expect(refundRefProblem('PAYU-1'), isNull);
    });

    test('a refund’s answer is read as done or as waiting for approval', () {
      expect(RefundOutcome.fromJson({'refunded': true, 'refundRef': 'R-1'}), isA<RefundDone>());
      final pending = RefundOutcome.fromJson({
        'approvalRequired': true,
        'approval': {'id': 'ap-9', 'amountPaisa': 1500000},
      });
      expect(pending, isA<RefundPending>());
      expect((pending as RefundPending).amountPaisa, 1500000);
      expect(approvalSentBody(1500000), startsWith('₹15,000 is above the limit one person can approve alone'));
    });
  });

  group('Manage Events: the list', () {
    testWidgets('lists every event with its type, host, day, seats and status, and searches through the API', (
      tester,
    ) async {
      await pumpConsole(tester);
      expect(find.text('Manage Events'), findsOneWidget);
      expect(find.text('3 events'), findsOneWidget);
      expect(find.text('FM Leaders Summit', findRichText: true), findsOneWidget);
      expect(find.text('4 Dec 2026 · 10:00 AM · 42 / 200 going'), findsOneWidget);
      // One status each: live, hidden, ended.
      expect(find.text('Published'), findsOneWidget);
      expect(find.text('Hidden'), findsOneWidget);
      expect(find.text('Ended'), findsOneWidget);
      // A partner's event names its company.
      expect(find.textContaining('GreenGrid Services', findRichText: true), findsOneWidget);

      await search(tester, 'events.search', 'webinar');
      expect(repo.queries.last.search, 'webinar');
      expect(find.byKey(const ValueKey('event-e2')), findsOneWidget);
      expect(find.byKey(const ValueKey('event-e1')), findsNothing);
      expect(find.text('1 event'), findsOneWidget);

      await search(tester, 'events.search', 'nothing like this');
      expect(find.text('No Events Match'), findsOneWidget);
      await tapOn(tester, find.text('Clear Search and Filters'));
      expect(find.text('3 events'), findsOneWidget);
    });

    testWidgets('the filters are asked of the API: when, type and host', (tester) async {
      await pumpConsole(tester);
      await tapOn(tester, find.byKey(const ValueKey('events.when.past')));
      expect(repo.queries.last.when, 'past');
      expect(find.byKey(const ValueKey('event-e3')), findsOneWidget);
      expect(find.byKey(const ValueKey('event-e1')), findsNothing);

      await tapOn(tester, find.byKey(const ValueKey('events.when.all')));
      await tapOn(tester, find.byKey(const ValueKey('events.host')));
      await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text('Partner Events')));
      await tester.pumpAndSettle();
      expect(repo.queries.last.host, 'partner');
      expect(find.byKey(const ValueKey('event-e2')), findsOneWidget);
      expect(find.byKey(const ValueKey('event-e1')), findsNothing);

      await tapOn(tester, find.byKey(const ValueKey('events.kind')));
      await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text('Conference')));
      await tester.pumpAndSettle();
      expect(repo.queries.last.kind, 'CONFERENCE');
      expect(find.text('No Events Match'), findsOneWidget);
    });

    testWidgets('a search under a filter also offers the matches the filter leaves out', (tester) async {
      await pumpConsole(tester);
      await tapOn(tester, find.byKey(const ValueKey('events.when.past')));
      await search(tester, 'events.search', 'summit');
      expect(find.text('No Events Match'), findsOneWidget);
      expect(find.text('Other Matches'), findsOneWidget);
      expect(find.byKey(const ValueKey('event-match-e1')), findsOneWidget);
    });

    testWidgets('a row opens the event’s manage page inside the wrapper the app passes', (tester) async {
      await pumpConsole(tester);
      expect(find.byKey(const Key('bottom-bar')), findsNothing);
      await tapOn(tester, find.byKey(const ValueKey('event-e1')));
      expect(find.text('Manage Event'), findsOneWidget);
      expect(find.byKey(const Key('bottom-bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('event.heading')), findsOneWidget);
      expect(find.text('Friday, 4 December 2026'), findsOneWidget);
      expect(find.text('10:00 AM – 5:00 PM IST'), findsOneWidget);
      expect(find.text('42 going of 200 seats · 3 on the waitlist'), findsOneWidget);
      expect(find.text('₹1,500 (GST added at checkout)'), findsOneWidget);
      expect(find.text('Open until 25 Nov 2026'), findsOneWidget);
    });
  });

  group('the event form', () {
    testWidgets('refuses what the API would: no title or start, a zero capacity, a price past the limit, an end '
        'before the start', (tester) async {
      final pickers = FakePickers(
        days: [DateTime(2026, 12, 1), DateTime(2026, 12, 1)],
        times: const [TimeOfDay(hour: 10, minute: 0), TimeOfDay(hour: 9, minute: 0)],
      );
      await pumpConsole(tester, pickers: pickers);
      await tapOn(tester, find.byKey(const ValueKey('events.new')));
      expect(find.text('Create Event'), findsWidgets);

      await save(tester);
      expect(find.text('Enter the event’s title.'), findsOneWidget);
      expect(find.text('Select when the event starts.'), findsOneWidget);
      expect(repo.created, isEmpty);

      await type(tester, 'event.title', 'Workplace Summit');
      await type(tester, 'event.capacity', '0');
      await type(tester, 'event.price', '2000000');
      await tapOn(tester, selectField('event.startsAt'));
      await tapOn(tester, selectField('event.endsAt'));
      expect(find.text('1 Dec 2026, 10:00 AM IST'), findsOneWidget);
      await save(tester);
      expect(find.text('Enter a whole number, 1 or more. Leave it blank for unlimited.'), findsOneWidget);
      expect(find.text('A ticket can cost ₹1,000,000 at most.'), findsOneWidget);
      expect(find.text('The end must be after the start.'), findsOneWidget);
      expect(repo.created, isEmpty);

      await type(tester, 'event.capacity', '50');
      await type(tester, 'event.price', '1500');
      await tapOn(tester, find.byTooltip('Clear Ends'));
      await type(tester, 'event.about.overview', 'A day on the modern workplace.');
      await type(tester, 'event.about.agenda', '10:00 — Coffee\n11:00 — Talks');
      await save(tester);

      expect(repo.created, hasLength(1));
      final body = repo.created.single;
      expect(body['title'], 'Workplace Summit');
      // A new event's address follows its title.
      expect(body['slug'], 'workplace-summit');
      expect(body['kind'], 'CHAPTER_MEET');
      expect(body['capacity'], 50);
      expect(body['priceAmount'], 150000);
      // 10:00 on the Indian clock.
      expect(body['startsAt'], '2026-12-01T04:30:00.000Z');
      expect(body.containsKey('endsAt'), isFalse);
      expect(body['published'], true);
      expect(body['inviteOnly'], false);
      expect(body['callForSpeakersUntil'], isNull);
      expect(
        body['description'],
        '<p>A day on the modern workplace.</p>\n<h3>Agenda</h3>\n<ul>\n<li>10:00 — Coffee</li>\n<li>11:00 — Talks</li>\n</ul>',
      );
      expect(find.text('Event created.'), findsOneWidget);
      expect(find.text('Workplace Summit', findRichText: true), findsOneWidget);
    });

    testWidgets('keeps what was typed and shows the API’s own sentence when it refuses', (tester) async {
      final pickers = FakePickers(days: [DateTime(2026, 12, 1)], times: const [TimeOfDay(hour: 10, minute: 0)]);
      await pumpConsole(tester, pickers: pickers);
      await tapOn(tester, find.byKey(const ValueKey('events.new')));
      await type(tester, 'event.title', 'Taken');
      await tapOn(tester, selectField('event.startsAt'));
      await save(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('sheet.error')),
          matching: find.text('An event already uses this address.'),
        ),
        findsOneWidget,
      );
      expect(find.text('Taken'), findsOneWidget);
      expect(repo.created, isEmpty);
    });

    testWidgets('edits an event with every field filled from it, and clears what was cleared', (tester) async {
      await pumpEvent(tester, 'e1');
      await tapOn(tester, find.byKey(const ValueKey('event.edit')));
      // The page's button, and now the sheet's title.
      expect(find.text('Edit Event'), findsNWidgets(2));
      // The stored description arrives as the form's fields.
      expect(find.text('Two days of facility leadership.'), findsWidgets);
      expect(find.text('Keynote\nPanel'), findsOneWidget);
      expect(find.text('4 Dec 2026, 10:00 AM IST'), findsOneWidget);

      await type(tester, 'event.title', 'FM Leaders Summit 2026');
      await type(tester, 'event.capacity', '');
      await tapOn(tester, find.byKey(const Key('event.inviteOnly')));
      await save(tester);

      expect(repo.updated, hasLength(1));
      final (id, body) = repo.updated.single;
      expect(id, 'e1');
      expect(body['title'], 'FM Leaders Summit 2026');
      // An existing event keeps its address when its title changes.
      expect(body['slug'], 'fm-leaders-summit');
      expect(body.containsKey('capacity'), isTrue);
      expect(body['capacity'], isNull);
      expect(body['inviteOnly'], true);
      expect(body['priceAmount'], 150000);
      expect(body['endsAt'], '2026-12-04T11:30:00.000Z');
      expect(body['callForSpeakersUntil'], '2026-11-25T12:00:00.000Z');
      expect(find.text('Event saved.'), findsOneWidget);
      expect(find.text('FM Leaders Summit 2026'), findsOneWidget);
    });

    testWidgets('offers venue suggestions as the address is typed', (tester) async {
      await pumpEvent(tester, 'e1');
      await tapOn(tester, find.byKey(const ValueKey('event.edit')));
      await tester.ensureVisible(find.byKey(const Key('event.location')));
      await tester.enterText(find.byKey(const Key('event.location')), 'Taj');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      await tapOn(tester, find.text('Taj Mahal Palace, Colaba, Mumbai'));
      await save(tester);
      expect(repo.updated.single.$2['location'], 'Taj Mahal Palace, Colaba, Mumbai');
    });

    testWidgets('removes an event only after it is confirmed', (tester) async {
      var left = 0;
      await pumpEvent(tester, 'e2', onBack: () => left += 1);
      await tapOn(tester, find.byKey(const ValueKey('event.remove')));
      expect(find.text('Cancel and remove "Energy Audits Webinar" from the public calendar?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.deleted, isEmpty);

      await tapOn(tester, find.byKey(const ValueKey('event.remove')));
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();
      expect(repo.deleted, ['e2']);
      expect(left, 1);
    });
  });

  group('one event: the guest list', () {
    testWidgets('invites by email, reports the addresses that are not members, and refuses a bad address', (
      tester,
    ) async {
      await pumpEvent(tester, 'e1');
      await openTab(tester, 1);
      expect(find.text('1 Invited'), findsOneWidget);
      expect(find.text('Asha Menon'), findsOneWidget);
      expect(find.textContaining('This event is open to everyone.'), findsOneWidget);

      await tapOn(tester, find.byKey(const ValueKey('invite.byEmail')));
      await type(tester, 'invite.emails', 'zoya@acme.com, not-an-email');
      await save(tester);
      expect(find.text('not-an-email is not an email address.'), findsOneWidget);
      expect(repo.invitedEmails, isEmpty);

      await type(tester, 'invite.emails', 'zoya@acme.com, nobody@x.com');
      await save(tester);
      expect(repo.invitedEmails.single, ['zoya@acme.com', 'nobody@x.com']);
      expect(find.text('1 invited · not members: nobody@x.com'), findsOneWidget);
      expect(find.text('2 Invited'), findsOneWidget);
      expect(find.text('Zoya Khan'), findsOneWidget);
    });

    testWidgets('invites a whole tier and says how many were new', (tester) async {
      await pumpEvent(tester, 'e1');
      await openTab(tester, 1);
      await tapOn(tester, find.byKey(const ValueKey('invite.byTier')));
      expect(find.text('Gold and Above'), findsOneWidget);
      await save(tester);
      expect(repo.tierSweeps, ['GOLD']);
      expect(find.text('3 new invites from 40 members on Gold or above.'), findsOneWidget);
    });

    testWidgets('revokes an invite once it is confirmed', (tester) async {
      await pumpEvent(tester, 'e1');
      await openTab(tester, 1);
      await tapOn(tester, find.byKey(const ValueKey('invite-revoke-u1')));
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();
      expect(find.text('Asha Menon'), findsNothing);
      expect(find.text('0 Invited'), findsOneWidget);
    });
  });

  group('one event: speakers and sponsors', () {
    testWidgets('a talk is declined only with a reason, and accepted without one', (tester) async {
      await pumpEvent(tester, 'e1');
      expect(find.text('Speakers (2 to review)'), findsOneWidget);
      await openTab(tester, 2);
      await tapOn(tester, find.byKey(const ValueKey('proposal-p1')));
      expect(find.text('Talk Proposal'), findsOneWidget);
      await tapOn(tester, find.byKey(const Key('decision.decline')));
      expect(find.text('Enter the reason first.'), findsOneWidget);
      expect(repo.proposalDecisions, isEmpty);

      await type(tester, 'decision.note', 'Too close to last year’s keynote.');
      await tapOn(tester, find.byKey(const Key('decision.decline')));
      expect(repo.proposalDecisions.single, ('p1', 'DECLINED', 'Too close to last year’s keynote.'));
      expect(find.text('Declined'), findsOneWidget);
      expect(find.text('Speakers (1 to review)'), findsOneWidget);

      await tapOn(tester, find.byKey(const ValueKey('proposal-p2')));
      await tapOn(tester, find.byKey(const Key('decision.accept')));
      expect(repo.proposalDecisions.last, ('p2', 'ACCEPTED', null));
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Speakers (0 to review)'), findsOneWidget);
    });

    testWidgets('a package is added within the API’s limits, and removed after a confirmation', (tester) async {
      await pumpEvent(tester, 'e1');
      await openTab(tester, 3);
      expect(find.text('Silver partner · ₹25,000'), findsOneWidget);

      await tapOn(tester, find.byKey(const ValueKey('package.add')));
      await type(tester, 'package.name', 'Gold Partner');
      await type(tester, 'package.price', '50000');
      await type(tester, 'package.slots', '0');
      await save(tester);
      expect(find.textContaining('Enter a whole number from 1 to 1,000'), findsWidgets);
      expect(repo.packageBodies, isEmpty);

      await type(tester, 'package.slots', '2');
      await type(tester, 'package.benefits', 'Logo on stage\nA booth');
      await save(tester);
      expect(repo.packageBodies.single, {
        'name': 'Gold Partner',
        'priceAmount': 5000000,
        'benefits': ['Logo on stage', 'A booth'],
        'slots': 2,
      });
      expect(find.text('Gold Partner · ₹50,000 · 0/2 taken'), findsOneWidget);
      expect(find.text('Logo on stage · A booth'), findsOneWidget);

      await tapOn(tester, find.byKey(const ValueKey('package-k1')));
      expect(find.text('Edit Package'), findsOneWidget);
      await tapOn(tester, find.byKey(const Key('sheet.delete')));
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();
      expect(find.text('Silver partner · ₹25,000'), findsNothing);
      expect(find.text('Package removed.'), findsOneWidget);
    });

    testWidgets('a sponsorship request is confirmed from its sheet', (tester) async {
      await pumpEvent(tester, 'e1');
      await openTab(tester, 3);
      await tapOn(tester, find.byKey(const ValueKey('sponsorship-s1')));
      expect(find.text('Sponsorship Request'), findsOneWidget);
      await tapOn(tester, find.byKey(const Key('decision.accept')));
      expect(repo.sponsorshipDecisions.single, ('s1', 'CONFIRMED', null));
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Sponsors (0 to decide)'), findsOneWidget);
    });
  });

  group('one event: tickets', () {
    testWidgets('a refund at or below the limit is recorded at once, with its reference', (tester) async {
      await pumpEvent(tester, 'e1');
      await openTab(tester, 4);
      expect(find.text('₹1,770'), findsOneWidget);
      expect(find.text('kiran@corp.in · code EARLY10'), findsOneWidget);

      await tapOn(tester, find.byKey(const ValueKey('ticket-t1')));
      expect(
        find.text('Refund ₹1,770 to Kiran in the PayU dashboard first, then record it here. Their seat is released.'),
        findsOneWidget,
      );
      // Without a reference the API refuses a refund it would carry out now; its sentence stays in the sheet.
      await save(tester);
      expect(find.text('Add the gateway, bank or UPI reference of the money sent.'), findsOneWidget);

      await type(tester, 'refund.ref', 'PAYU-REF-1');
      await save(tester);
      expect(repo.refunds.last, ('t1', 'PAYU-REF-1'));
      expect(find.text('Refund recorded.'), findsOneWidget);
      expect(find.text('Refunded'), findsOneWidget);
      expect(find.text('Refund reference: PAYU-REF-1'), findsOneWidget);
      expect(find.byKey(const ValueKey('refund.pending')), findsNothing);
    });

    testWidgets('a refund above the limit waits for a second approver, and says so as the website does', (
      tester,
    ) async {
      await pumpEvent(tester, 'e1');
      await openTab(tester, 4);
      await tapOn(tester, find.byKey(const ValueKey('ticket-t2')));
      // The reference may be left for the approver.
      await save(tester);
      expect(repo.refunds.single, ('t2', null));
      expect(find.text('Sent for Approval'), findsOneWidget);
      expect(
        find.text(
          '₹15,000 is above the limit one person can approve alone. Another finance approver must '
          'approve it. Nothing has been recorded yet.',
        ),
        findsOneWidget,
      );
      // Nothing was recorded: the ticket is still paid.
      expect(find.text('Refunded'), findsNothing);
      expect(find.text('Refund recorded.'), findsNothing);
    });

    testWidgets('a free event says it sells no tickets', (tester) async {
      await pumpEvent(tester, 'e3');
      await openTab(tester, 4);
      expect(find.text('No Tickets Sold Yet'), findsOneWidget);
      expect(find.text('This event is free, so it sells no tickets.'), findsOneWidget);
    });
  });

  group('one event: attendance', () {
    testWidgets('marks who came once the event has started, and reports the CPD hours', (tester) async {
      await pumpEvent(tester, 'e3');
      await openTab(tester, 5);
      expect(find.text('25 going · no seat limit'), findsOneWidget);
      await tapOn(tester, find.byKey(const ValueKey('attendance.mark')));
      await tapOn(tester, find.byKey(const Key('attendance.all')));
      await save(tester);
      expect(repo.attendance.single, unorderedEquals(['u7', 'u8']));
      expect(
        find.text('1 marked present · 2 CPD hours each. 1 had no place at this event, so was not marked.'),
        findsOneWidget,
      );
    });

    testWidgets('an event that has not started offers nothing to mark', (tester) async {
      await pumpEvent(tester, 'e1');
      await openTab(tester, 5);
      expect(find.text('Attendance can be marked once the event has started.'), findsOneWidget);
      expect(find.byKey(const ValueKey('attendance.mark')), findsNothing);
    });
  });

  group('Event Partners', () {
    testWidgets('opens on the waiting requests with their number; a rejection needs a reason', (tester) async {
      await pumpConsole(tester, initialTab: 'event-hosts');
      expect(find.text('Waiting (2)'), findsOneWidget);
      expect(find.text('GreenGrid Services'), findsOneWidget);
      expect(find.text('Urban Estates'), findsNothing);
      expect(find.text('Roundtable, Webinar · Quarterly'), findsNWidgets(2));

      await tapOn(tester, find.byKey(const ValueKey('host-h1')));
      expect(find.text('Request to Host Events'), findsOneWidget);
      await tapOn(tester, find.byKey(const Key('host.reject')));
      expect(find.text('Give the company a reason. They will see it.'), findsOneWidget);
      expect(repo.hostDecisions, isEmpty);

      await type(tester, 'host.note', 'Please apply again once your company page is verified.');
      await tapOn(tester, find.byKey(const Key('host.reject')));
      expect(repo.hostDecisions.single, ('h1', 'reject', 'Please apply again once your company page is verified.'));
      expect(find.text('Request rejected.'), findsOneWidget);
      expect(find.byKey(const ValueKey('host-h1')), findsNothing);
      expect(find.text('Waiting (1)'), findsOneWidget);
    });

    testWidgets('approves a request, with or without a note', (tester) async {
      await pumpConsole(tester, initialTab: 'event-hosts');
      await tapOn(tester, find.byKey(const ValueKey('host-h2')));
      await tapOn(tester, find.byKey(const Key('host.approve')));
      expect(repo.hostDecisions.single, ('h2', 'approve', null));
      expect(find.text('Skyline Facilities can now host events.'), findsOneWidget);
      expect(find.text('Waiting (1)'), findsOneWidget);
    });

    testWidgets('revokes an approved company’s hosting, with the reason', (tester) async {
      await pumpConsole(tester, initialTab: 'event-hosts');
      await tapOn(tester, find.byKey(const ValueKey('hosts.status.APPROVED')));
      await tapOn(tester, find.byKey(const ValueKey('host-h3')));
      expect(find.text('Events Hosted'), findsOneWidget);
      await tapOn(tester, find.byKey(const Key('host.revoke')));
      expect(find.text('Give the company a reason. They will see it.'), findsOneWidget);
      await type(tester, 'host.note', 'Two events were cancelled without notice.');
      await tapOn(tester, find.byKey(const Key('host.revoke')));
      expect(repo.hostDecisions.single, ('h3', 'revoke', 'Two events were cancelled without notice.'));
      expect(find.text('Hosting revoked.'), findsOneWidget);
      expect(find.text('No Requests Match'), findsOneWidget);
    });

    testWidgets('a notification’s request opens on its own, whatever its standing', (tester) async {
      await pumpConsole(tester, focus: 'h3');
      // Every standing is listed, so an approved request is there to open.
      expect(find.text('Request to Host Events'), findsOneWidget);
      expect(find.descendant(of: find.byType(EmSheet), matching: find.text('Urban Estates')), findsOneWidget);
      expect(find.byKey(const Key('host.revoke')), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('every page and tab lays out on a 360 dp phone and on a tablet', (tester) async {
      for (final (width, height) in const [(360.0, 640.0), (840.0, 1100.0)]) {
        repo = FakeEventsRepository();
        await pumpConsole(tester, width: width, height: height);
        expect(tester.takeException(), isNull);
        await tapOn(tester, find.byKey(const ValueKey('manage-events-tab-1')));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());

        await pumpEvent(tester, 'e1', width: width, height: height);
        for (var tab = 0; tab < 6; tab++) {
          await openTab(tester, tab);
          expect(tester.takeException(), isNull, reason: 'tab $tab at $width dp');
        }
        await openTab(tester, 0);
        await tapOn(tester, find.byKey(const ValueKey('event.edit')));
        expect(tester.takeException(), isNull, reason: 'the event form at $width dp');
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
