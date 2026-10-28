import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/messaging/api_messaging_repository.dart';
import 'package:icr_mobile/features/messaging/messaging_models.dart';
import 'package:icr_mobile/features/messaging/messaging_repository.dart';

import 'messaging_fakes.dart';

/// Every call the Messages screens make, against answers shaped like the real
/// API's (captured from the local portal on 26 Oct 2026, abridged): what is
/// sent, and how each answer reads. What the API does for real is proved in
/// `test/live/messaging_live_test.dart`.
void main() {
  Map<String, dynamic> person(String id, String first, String last, [String? avatar]) => {
    'id': id,
    'firstName': first,
    'lastName': last,
    'avatarUrl': avatar,
  };

  final bharat = person('u-bharat', 'Bharat', 'Buyer', '/uploads/design-persona-me.jpg');
  final sarahJson = person('u-sarah', 'Sarah', 'Jenkins', '/uploads/design-home-avatar_sarah.jpg');

  Map<String, dynamic> message(
    String id,
    String conv,
    Map<String, dynamic> from, {
    String body = 'Hello',
    Map<String, dynamic>? company,
    String? readAt,
    String? deletedAt,
    String at = '2026-10-25T05:38:54.282Z',
    Map<String, dynamic>? replyTo,
    String? attachmentUrl,
  }) => {
    'id': id,
    'conversationId': conv,
    'senderId': from['id'],
    'senderCompanyId': company?['id'],
    'body': body,
    'attachmentUrl': attachmentUrl,
    'attachmentName': attachmentUrl == null ? null : 'Site feasibility checklist.pdf',
    'attachmentSize': attachmentUrl == null ? null : 1300,
    'attachmentMime': attachmentUrl == null ? null : 'application/pdf',
    'replyToId': replyTo?['id'],
    'readAt': readAt,
    'deletedAt': deletedAt,
    'createdAt': at,
    'sender': from,
    'senderCompany': company,
    'replyTo': replyTo,
  };

  /// `GET /messaging/conversations` rows, as seeded: direct, a company's careers inbox, a requirement.
  Map<String, dynamic> list() => {
    'data': [
      {
        'id': 'conv-sarah',
        'title': null,
        'rfqId': null,
        'createdAt': '2026-10-23T04:32:54.282Z',
        'updatedAt': '2026-10-25T05:38:54.282Z',
        'participants': [bharat, sarahJson],
        'parties': <dynamic>[],
        'asCompanyId': null,
        'messages': [message('m-sarah-5', 'conv-sarah', sarahJson, body: 'Happy to jump on a quick call this week.')],
        'rfq': null,
        'unread': 2,
        'starred': false,
        'pinned': false,
        'kind': 'DIRECT',
        'contextLabel': null,
        'counterpartCompany': null,
      },
      {
        'id': 'conv-company',
        'title': null,
        'rfqId': null,
        'createdAt': '2026-10-22T06:07:54.282Z',
        'updatedAt': '2026-10-25T01:12:54.282Z',
        'participants': [bharat],
        'parties': [
          {
            'companyId': 'co-gi',
            'name': 'Global Infra Solutions',
            'logoUrl': '/uploads/design-lj-company-logo.png',
            'topic': 'CAREERS',
          },
        ],
        'asCompanyId': null,
        'messages': [
          message(
            'm-co-3',
            'conv-company',
            person('u-priya', 'Priya', 'Sharma'),
            body: 'We would like to set up an introductory call on Thursday.',
            company: {
              'id': 'co-gi',
              'name': 'Global Infra Solutions',
              'logoUrl': '/uploads/design-lj-company-logo.png',
            },
          ),
        ],
        'rfq': null,
        'unread': 1,
        'starred': false,
        'pinned': false,
        'kind': 'COMPANY',
        'contextLabel': null,
        'counterpartCompany': {
          'id': 'co-gi',
          'name': 'Global Infra Solutions',
          'logoUrl': '/uploads/design-lj-company-logo.png',
        },
      },
      {
        'id': 'conv-rfq',
        'title': 'Annual Housekeeping Contract — Mumbai HQ',
        'rfqId': 'rfq-1',
        'createdAt': '2026-10-24T06:07:54.282Z',
        'updatedAt': '2026-10-24T10:12:54.282Z',
        'participants': [bharat],
        'parties': [
          {'companyId': 'co-care', 'name': 'Bengaluru Care 101', 'logoUrl': null, 'topic': 'SALES'},
        ],
        'asCompanyId': null,
        'messages': <dynamic>[],
        'rfq': {'id': 'rfq-1', 'title': 'Annual Housekeeping Contract — Mumbai HQ', 'kind': 'RFQ'},
        'unread': 0,
        'starred': true,
        'pinned': true,
        'kind': 'REQUIREMENT',
        'contextLabel': 'Annual Housekeeping Contract — Mumbai HQ',
        'counterpartCompany': {'id': 'co-care', 'name': 'Bengaluru Care 101', 'logoUrl': null},
      },
    ],
    'meta': {'page': 1, 'limit': 25, 'total': 3, 'totalPages': 1, 'hasNext': true, 'hasPrev': false},
  };

  ApiMessagingRepository repoOf(TableAdapter adapter, {String? viewerId}) =>
      ApiMessagingRepository(api: clientFor(adapter), viewerId: viewerId);

  group('the list', () {
    test(
      'a direct thread, a company\'s inbox thread and a requirement all read, with their kind, parties and last word',
      () async {
        final adapter = TableAdapter({'GET /messaging/conversations': (_) => list()});
        final page = await repoOf(adapter).conversations(const ConversationQuery());
        expect(page.total, 3);
        expect(page.hasMore, isTrue);
        final [sarah, company, rfq] = page.conversations;

        expect(sarah.kind, ConversationKind.direct);
        expect(sarah.unread, 2);
        expect(sarah.participants.map((p) => p.fullName), ['Bharat Buyer', 'Sarah Jenkins']);
        expect(sarah.participants.last.photo!.url, 'http://api.test/uploads/design-home-avatar_sarah.jpg');
        expect(sarah.lastMessage!.body, 'Happy to jump on a quick call this week.');
        expect(sarah.updatedAt, DateTime.utc(2026, 10, 25, 5, 38, 54, 282));

        expect(company.kind, ConversationKind.company);
        expect(company.parties.single.topic, 'CAREERS');
        expect(company.parties.single.mine, isFalse, reason: 'a reader outside the company is told no status');
        expect(company.counterpartCompany!.name, 'Global Infra Solutions');
        expect(company.counterpartCompany!.logo!.url, 'http://api.test/uploads/design-lj-company-logo.png');
        expect(company.lastMessage!.senderCompany!.id, 'co-gi');

        expect(rfq.kind, ConversationKind.requirement);
        expect((rfq.rfqId, rfq.rfqTitle), ('rfq-1', 'Annual Housekeeping Contract — Mumbai HQ'));
        expect(rfq.contextLabel, 'Annual Housekeeping Contract — Mumbai HQ');
        expect((rfq.starred, rfq.pinned), (true, true));
        expect(rfq.lastMessage, isNull);
      },
    );

    test('a row of a company inbox carries its side, the party\'s status and who it is assigned to', () async {
      final adapter = TableAdapter({
        'GET /messaging/conversations': (_) => {
          'data': [
            {
              'id': 'c1',
              'title': null,
              'participants': [bharat],
              'parties': [
                {
                  'companyId': 'co-care',
                  'name': 'Bengaluru Care 101',
                  'logoUrl': null,
                  'topic': 'SALES',
                  'status': 'OPEN',
                  'assignee': person('u-vik', 'Vikram', 'Vendor'),
                },
              ],
              'asCompanyId': 'co-care',
              'messages': <dynamic>[],
              'unread': 0,
              'kind': 'REQUIREMENT',
              'updatedAt': '2026-10-24T10:12:54.282Z',
            },
          ],
          'meta': {'total': 1, 'hasNext': false},
        },
      });
      final c = (await repoOf(adapter).conversations(const ConversationQuery(inbox: 'co-care'))).conversations.single;
      expect(c.asCompanyId, 'co-care');
      expect(c.myParty!.status, ThreadStatus.open);
      expect(c.myParty!.assignee!.fullName, 'Vikram Vendor');
      expect(c.myParties, hasLength(1));
    });

    test('every filter is the query the website sends', () {
      Map<String, dynamic> q(ConversationQuery query, {int page = 1}) =>
          ApiMessagingRepository.listQuery(query, page: page);
      expect(q(const ConversationQuery()), {
        'page': 1,
        'limit': 25,
        'inbox': 'personal',
        'filter': 'all',
        'excludePinned': true,
      });
      expect(q(const ConversationQuery(filter: InboxFilter.unread), page: 2), {
        'page': 2,
        'limit': 25,
        'inbox': 'personal',
        'filter': 'unread',
      });
      expect(q(const ConversationQuery(filter: InboxFilter.starred)), containsPair('filter', 'starred'));
      expect(q(const ConversationQuery(kind: InboxKind.mentorship)), containsPair('kind', 'mentorship'));
      expect(q(const ConversationQuery(search: ' crane ')), containsPair('search', 'crane'));
      expect(q(const ConversationQuery(search: ' crane ')), isNot(contains('excludePinned')));
      // A company inbox: its views, topic, no person filters.
      const co = ConversationQuery(inbox: 'co-acme');
      expect(q(co), {'page': 1, 'limit': 25, 'inbox': 'co-acme'});
      expect(q(co.copyWith(view: CompanyInboxView.unread)), containsPair('filter', 'unread'));
      expect(q(co.copyWith(view: CompanyInboxView.mine)), containsPair('assignedToMe', true));
      expect(q(co.copyWith(view: CompanyInboxView.done)), containsPair('status', 'DONE'));
      expect(q(co.copyWith(view: CompanyInboxView.spam)), containsPair('status', 'SPAM'));
      expect(q(co.copyWith(topic: 'SALES')), containsPair('topic', 'SALES'));
      expect(q(co.copyWith(kind: InboxKind.direct)), isNot(contains('kind')));
    });

    test('the pinned list, message search and the unread counts', () async {
      final adapter = TableAdapter({
        'GET /messaging/conversations': (_) => list(),
        'GET /messaging/search': (_) => {
          'data': [
            {
              'messageId': 'm-david-1',
              'conversationId': 'conv-david',
              'conversationTitle': null,
              'participants': [bharat, person('u-david', 'David', 'Chen')],
              'sender': person('u-david', 'David', 'Chen'),
              'senderCompany': null,
              'snippet': '…the checklist we use for new campus sites.',
              'createdAt': '2026-10-22T07:40:11.112Z',
            },
          ],
        },
        'GET /messaging/unread-count': (_) => {
          'count': 5,
          'personal': 4,
          'companies': {'co-acme': 1},
        },
        'GET /messaging/inboxes': (_) => [
          {'id': 'personal', 'kind': 'personal', 'unread': 4},
          {
            'id': 'co-acme',
            'kind': 'company',
            'name': 'Acme FM',
            'logoUrl': null,
            'topics': ['SALES', 'PROCUREMENT'],
            'unread': 1,
          },
        ],
      });
      final repo = repoOf(adapter);
      await repo.pinned();
      expect(adapter.queryOf('GET /messaging/conversations'), {'filter': 'pinned', 'limit': 10});

      expect(await repo.searchMessages('c'), isEmpty, reason: 'under two letters is not sent');
      expect(adapter.calls.where((c) => c.contains('search')), isEmpty);
      final hits = await repo.searchMessages(' checklist ', inbox: 'personal');
      expect(adapter.queryOf('GET /messaging/search'), {'q': 'checklist', 'limit': 20, 'inbox': 'personal'});
      expect(hits.single.snippet, startsWith('…the checklist'));
      expect(hits.single.sender!.firstName, 'David');
      expect(hits.single.conversationId, 'conv-david');

      final unread = await repo.unreadCount();
      expect((unread.count, unread.personal), (5, 4));
      expect(unread.companies, {'co-acme': 1});

      final inboxes = await repo.inboxes();
      expect(inboxes.map((i) => (i.id, i.personal, i.unread)), [('personal', true, 4), ('co-acme', false, 1)]);
      expect(inboxes.last.name, 'Acme FM');
      expect(inboxes.last.topics, ['SALES', 'PROCUREMENT']);
    });

    test('mark all as read: the whole account, or one inbox', () async {
      final adapter = TableAdapter({
        'POST /messaging/conversations/read-all': (_) => {'read': 4, 'conversations': 2},
      });
      final repo = repoOf(adapter);
      expect(await repo.markAllRead(), 4);
      expect(adapter.queryOf('POST /messaging/conversations/read-all'), isEmpty);
      await repo.markAllRead(inbox: 'co-acme');
      expect(adapter.queryOf('POST /messaging/conversations/read-all'), {'inbox': 'co-acme'});
    });
  });

  group('a thread', () {
    final detail = {
      'id': 'conv-david',
      'title': null,
      'rfqId': null,
      'createdAt': '2026-10-21T05:37:54.282Z',
      'updatedAt': '2026-10-22T06:12:54.282Z',
      'participants': [bharat, person('u-david', 'David', 'Chen')],
      'messages': [
        message(
          'm-3',
          'conv-david',
          person('u-david', 'David', 'Chen'),
          body: '',
          deletedAt: '2026-10-21T06:32:54.282Z',
          at: '2026-10-21T06:12:54.282Z',
        ),
        message(
          'm-4',
          'conv-david',
          bharat,
          body: "Let's talk next week once the shortlist is in.",
          readAt: '2026-10-22T06:15:54.282Z',
          at: '2026-10-22T06:12:54.282Z',
        ),
      ],
      'rfq': null,
      'starred': true,
      'pinned': true,
      'parties': <dynamic>[],
      'asCompanyId': null,
      'hasMore': true,
      'seen': {'messageId': 'm-4', 'at': '2026-10-22T06:15:54.282Z'},
    };

    test(
      'the newest window: oldest first, withdrawn blanked, "seen", star and pin, and no kind (the list row has it)',
      () async {
        final adapter = TableAdapter({'GET /messaging/conversations/conv-david': (_) => detail});
        final w = await repoOf(adapter).thread('conv-david', take: 2);
        expect(adapter.queryOf('GET /messaging/conversations/conv-david'), {'take': 2});
        expect(w.hasMore, isTrue);
        expect(w.messages.map((m) => m.id), ['m-3', 'm-4']);
        expect(w.messages.first.deleted, isTrue);
        expect(w.messages.first.body, isEmpty);
        expect(w.messages.last.readAt, isNotNull);
        expect(w.seen!.messageId, 'm-4');
        expect(w.conversation.kind, isNull);
        expect((w.conversation.starred, w.conversation.pinned), (true, true));
      },
    );

    test('as a company\'s inbox: the side travels on every read', () async {
      final adapter = TableAdapter({'GET /messaging/conversations/c1': (_) => detail});
      await repoOf(adapter).thread('c1', asCompanyId: 'co-acme');
      expect(adapter.queryOf('GET /messaging/conversations/c1'), {'take': 50, 'asCompanyId': 'co-acme'});
    });

    test('earlier and later messages: before and after a message, oldest first, with "seen"', () async {
      final adapter = TableAdapter({
        'GET /messaging/conversations/c1/messages': (_) => {
          'data': [
            message('m-2', 'c1', bharat, at: '2026-10-21T05:00:00.000Z'),
            message('m-1', 'c1', bharat, at: '2026-10-21T05:00:00.000Z'),
          ],
          'hasMore': false,
          'seen': {'messageId': 'm-9', 'at': '2026-10-22T06:15:54.282Z'},
        },
      });
      final repo = repoOf(adapter);
      final older = await repo.older('c1', 'm-5', take: 20, asCompanyId: 'co-acme');
      expect(adapter.queryOf('GET /messaging/conversations/c1/messages'), {
        'before': 'm-5',
        'take': 20,
        'asCompanyId': 'co-acme',
      });
      expect(older.messages.map((m) => m.id), ['m-1', 'm-2'], reason: 'equal times keep a stable order by id');
      expect(older.seen!.messageId, 'm-9');
      await repo.newer('c1', 'm-5');
      expect(adapter.queryOf('GET /messaging/conversations/c1/messages'), {'after': 'm-5'});
    });

    test('a reply carries the message it quotes, and a withdrawn original', () async {
      final adapter = TableAdapter({
        'GET /messaging/conversations/c1': (_) => {
          ...detail,
          'messages': [
            message(
              'm-2',
              'c1',
              person('u-david', 'David', 'Chen'),
              body: 'Thanks!',
              replyTo: {
                'id': 'm-1',
                'senderId': 'u-bharat',
                'senderName': 'Bharat Buyer',
                'excerpt': '',
                'attachmentName': 'Brief.pdf',
                'deleted': true,
              },
            ),
          ],
        },
      });
      final m = (await repoOf(adapter).thread('c1')).messages.single;
      expect(m.replyTo!.senderName, 'Bharat Buyer');
      expect(m.replyTo!.deleted, isTrue);
      expect(m.replyTo!.attachmentName, 'Brief.pdf');
    });

    test('a file on a message: its name, size, kind', () async {
      final adapter = TableAdapter({
        'GET /messaging/conversations/c1': (_) => {
          ...detail,
          'messages': [message('m-1', 'c1', bharat, body: '', attachmentUrl: '/uploads/inbox-seed-site-checklist.pdf')],
        },
      });
      final m = (await repoOf(adapter).thread('c1')).messages.single;
      expect(m.hasAttachment, isTrue);
      expect(
        (m.attachmentName, m.attachmentSize, m.attachmentMime),
        ('Site feasibility checklist.pdf', 1300, 'application/pdf'),
      );
      expect(m.isImage, isFalse);
    });
  });

  group('why a thread exists (GET …/context)', () {
    test('a requirement: the company on the other side, the requirement, where the reader stands', () async {
      final adapter = TableAdapter({
        'GET /messaging/conversations/c1/context': (_) => {
          'kind': 'REQUIREMENT',
          'perspective': 'OWNER',
          'counterpart': {
            'person': null,
            'company': {
              'id': 'co-care',
              'name': 'Bengaluru Care 101',
              'logoUrl': null,
              'industry': null,
              'city': 'Bengaluru',
              'verified': true,
              'sells': true,
              'role': 'SUPPLIER',
            },
          },
          'requirement': {
            'id': 'rfq-1',
            'title': 'Annual Housekeeping',
            'kind': 'RFQ',
            'status': 'PUBLISHED',
            'budget': '1250000',
            'location': 'Mumbai',
            'dueDate': '2026-11-09T18:29:59.999Z',
          },
          'bid': {'amount': '485000', 'status': 'PENDING', 'awarded': false, 'mine': false},
          'mentorship': null,
          'groupSession': null,
          'consultation': null,
          'events': [
            {
              'id': 'ev1',
              'type': 'BID_SUBMITTED',
              'at': '2026-10-24T10:00:00.000Z',
              'amount': 485000,
              'mine': false,
              'label': null,
            },
          ],
        },
      });
      final c = (await repoOf(adapter).context('c1'))!;
      expect((c.kind, c.perspective), (ConversationKind.requirement, Perspective.owner));
      expect((c.company!.name, c.company!.verified, c.company!.role), ('Bengaluru Care 101', true, 'SUPPLIER'));
      expect(
        (c.requirement!.title, c.requirement!.budget, c.requirement!.isEnquiry),
        ('Annual Housekeeping', 1250000, false),
      );
      expect(c.requirement!.dueDate, DateTime.utc(2026, 11, 9, 18, 29, 59, 999));
      expect((c.bid!.amount, c.bid!.mine, c.bid!.awarded), (485000, false, false));
      expect(c.events.single.type, 'BID_SUBMITTED');
    });

    test('a company\'s thread and a plain one carry no requirement', () async {
      final adapter = TableAdapter({
        'GET /messaging/conversations/c1/context': (_) => {
          'kind': 'DIRECT',
          'perspective': 'OTHER',
          'counterpart': {'person': person('u-david', 'David', 'Chen'), 'company': null},
          'requirement': null,
          'bid': null,
          'mentorship': null,
          'groupSession': null,
          'consultation': null,
          'events': <dynamic>[],
        },
      });
      final c = (await repoOf(adapter).context('c1', asCompanyId: 'co-acme'))!;
      expect(adapter.queryOf('GET /messaging/conversations/c1/context'), {'asCompanyId': 'co-acme'});
      expect((c.kind, c.perspective, c.person!.fullName), (ConversationKind.direct, Perspective.other, 'David Chen'));
      expect(c.company, isNull);
      expect(c.requirement, isNull);
    });

    test('a mentorship, a group room and a consultation', () async {
      Map<String, dynamic> base(String kind) => {
        'kind': kind,
        'perspective': 'OTHER',
        'counterpart': {'person': null, 'company': null},
        'requirement': null,
        'bid': null,
        'mentorship': null,
        'groupSession': null,
        'consultation': null,
        'events': <dynamic>[],
      };
      final adapter = TableAdapter({
        'GET /messaging/conversations/m/context': (_) => {
          ...base('MENTORSHIP'),
          'mentorship': {
            'id': 'M1',
            'role': 'MENTEE',
            'mentorProfileId': 'MP1',
            'topics': ['IGBC'],
            'sessionsCount': 3,
            'nextSession': {'scheduledAt': '2026-10-27T05:30:00.000Z'},
          },
        },
        'GET /messaging/conversations/g/context': (_) => {
          ...base('GROUP_SESSION'),
          'groupSession': {'id': 'G1', 'title': 'BMS Clinic', 'nextAt': '2026-10-30T13:00:00.000Z'},
        },
        'GET /messaging/conversations/k/context': (_) => {
          ...base('CONSULTATION'),
          'consultation': {'id': 'P1', 'title': 'CV review', 'role': 'BUYER', 'type': 'QUERY', 'scheduledAt': null},
        },
      });
      final repo = repoOf(adapter);
      final m = (await repo.context('m'))!.mentorship!;
      expect((m.mentee, m.sessionsCount, m.nextSessionAt), (true, 3, DateTime.utc(2026, 10, 27, 5, 30)));
      expect(m.topics, ['IGBC']);
      final g = (await repo.context('g'))!.groupSession!;
      expect((g.title, g.nextAt), ('BMS Clinic', DateTime.utc(2026, 10, 30, 13)));
      final k = (await repo.context('k'))!.consultation!;
      expect((k.buyer, k.oneOnOne), (true, false), reason: 'QUERY is a written consultation, not a booked call');
    });

    test('a kind this app does not know is no context', () async {
      final adapter = TableAdapter({
        'GET /messaging/conversations/c1/context': (_) => {'kind': 'SOMETHING_NEW'},
      });
      expect(await repoOf(adapter).context('c1'), isNull);
    });
  });

  group('writing', () {
    test('send: the words, the file, the quoted message and the company it is sent as', () async {
      final adapter = TableAdapter({
        'POST /messaging/conversations/c1/messages': (o) => message('m-new', 'c1', bharat, body: 'ok'),
      });
      final repo = repoOf(adapter);
      final m = await repo.send('c1', body: 'ok');
      expect(m.id, 'm-new');
      expect(adapter.last('POST /messaging/conversations/c1/messages').data, {'body': 'ok'});
      await repo.send('c1', body: '', attachmentUrl: '/uploads/x.pdf', replyToId: 'm-1', asCompanyId: 'co-acme');
      expect(adapter.last('POST /messaging/conversations/c1/messages').data, {
        'body': '',
        'attachmentUrl': '/uploads/x.pdf',
        'replyToId': 'm-1',
        'asCompanyId': 'co-acme',
      });
    });

    test('read, delete, report, star and pin', () async {
      final adapter = TableAdapter({
        'POST /messaging/conversations/c1/read': (_) => {'read': 2},
        'DELETE /messaging/conversations/c1/messages/m-1': (_) => {
          'id': 'm-1',
          'deletedAt': '2026-10-26T08:00:00.000Z',
        },
        'POST /messaging/messages/m-1/report': (_) => {'id': 'r1'},
        'PATCH /messaging/conversations/c1/preferences': (_) => {'starred': true, 'pinned': false},
      });
      final repo = repoOf(adapter);
      await repo.markRead('c1', asCompanyId: 'co-acme');
      expect(adapter.queryOf('POST /messaging/conversations/c1/read'), {'asCompanyId': 'co-acme'});
      expect(await repo.deleteMessage('c1', 'm-1'), DateTime.utc(2026, 10, 26, 8));
      await repo.report('m-1', 'SPAM', note: '  junk  ');
      expect(adapter.last('POST /messaging/messages/m-1/report').data, {'reason': 'SPAM', 'note': 'junk'});
      await repo.report('m-1', 'FRAUD', note: '  ');
      expect(adapter.last('POST /messaging/messages/m-1/report').data, {'reason': 'FRAUD'});
      final saved = await repo.setPreference('c1', starred: true);
      expect(adapter.last('PATCH /messaging/conversations/c1/preferences').data, {'starred': true});
      expect(saved, (starred: true, pinned: false));
    });

    test('a company inbox sorts a thread: status, assignee, and "unassign" is an explicit null', () async {
      final adapter = TableAdapter({
        'PATCH /messaging/conversations/c1/company': (_) => {
          'companyId': 'co-acme',
          'name': 'Acme',
          'logoUrl': null,
          'topic': 'SALES',
          'status': 'DONE',
          'assignee': person('u-me', 'Me', 'Myself'),
        },
      });
      final repo = repoOf(adapter);
      final p = await repo.updateCompanyThread(
        'c1',
        companyId: 'co-acme',
        status: ThreadStatus.done,
        assigneeId: 'u-me',
      );
      expect(adapter.last('PATCH /messaging/conversations/c1/company').data, {
        'companyId': 'co-acme',
        'status': 'DONE',
        'assigneeId': 'u-me',
      });
      expect((p.status, p.assignee!.firstName), (ThreadStatus.done, 'Me'));
      await repo.updateCompanyThread('c1', companyId: 'co-acme', unassign: true);
      expect(adapter.last('PATCH /messaging/conversations/c1/company').data, {
        'companyId': 'co-acme',
        'assigneeId': null,
      });
    });

    test('the file is uploaded as a message attachment and comes back with its URL', () async {
      final adapter = TableAdapter({
        'POST /uploads': (_) => {
          'url': '/uploads/abc.pdf',
          'name': 'Quote.pdf',
          'size': 4,
          'mimeType': 'application/pdf',
        },
      });
      final up = await repoOf(
        adapter,
      ).upload(PickedAttachment(name: 'Quote.pdf', bytes: Uint8List.fromList([1, 2, 3, 4])));
      final req = adapter.last('POST /uploads');
      expect(req.queryParameters, {'purpose': 'message-attachment'});
      expect(req.data, isA<FormData>());
      expect((req.data as FormData).files.single.value.filename, 'Quote.pdf');
      expect((up.url, up.name, up.size, up.mimeType), ('/uploads/abc.pdf', 'Quote.pdf', 4, 'application/pdf'));
    });

    test('a private file is read from the API\'s own host with the person\'s session', () async {
      final adapter = TableAdapter({'GET http://api.test/uploads/inbox-seed-site-checklist.pdf': (_) => 'x'});
      await repoOf(adapter).download('/uploads/inbox-seed-site-checklist.pdf');
      expect(adapter.requests.single.uri.toString(), 'http://api.test/uploads/inbox-seed-site-checklist.pdf');
      expect(adapter.requests.single.responseType, ResponseType.bytes);
    });

    test('who "me" is: asked once, from the session\'s own user', () async {
      final adapter = TableAdapter({
        'GET /auth/me': (_) => {'id': 'u-bharat', 'email': 'buyer@icr.dev'},
      });
      final repo = repoOf(adapter);
      expect(await repo.viewerId(), 'u-bharat');
      expect(await repo.viewerId(), 'u-bharat');
      expect(adapter.calls, ['GET /auth/me']);
      expect(await repoOf(adapter, viewerId: 'known').viewerId(), 'known');
    });
  });

  group('starting a thread', () {
    test('who "New message" can reach: people with who they are, suppliers by listing', () async {
      final adapter = TableAdapter({
        'GET /messaging/recipients': (_) => {
          'people': [
            {...sarahJson, 'headline': 'Senior Facilities Manager at Google', 'companyName': null},
          ],
          'suppliers': [
            {
              'vendorId': 'v1',
              'companyId': 'co-care',
              'name': 'Bengaluru Care 101',
              'logoUrl': null,
              'city': 'Bengaluru',
            },
          ],
        },
      });
      final repo = repoOf(adapter);
      expect((await repo.recipients('s')).isEmpty, isTrue);
      expect(adapter.calls, isEmpty);
      final r = await repo.recipients(' sa ');
      expect(adapter.queryOf('GET /messaging/recipients'), {'search': 'sa'});
      expect(
        (r.people.single.person.fullName, r.people.single.headline),
        ('Sarah Jenkins', 'Senior Facilities Manager at Google'),
      );
      expect(
        (r.suppliers.single.vendorId, r.suppliers.single.companyId, r.suppliers.single.city),
        ('v1', 'co-care', 'Bengaluru'),
      );
    });

    test('the id of the thread is found in each shape the API answers with', () {
      expect(ApiMessagingRepository.conversationIdOf({'conversationId': 'a'}), 'a');
      expect(ApiMessagingRepository.conversationIdOf({'id': 'b', 'participants': []}), 'b');
      expect(
        ApiMessagingRepository.conversationIdOf({
          'conversation': {'id': 'c'},
        }),
        'c',
      );
      expect(ApiMessagingRepository.conversationIdOf({'nothing': 1}), isNull);
      expect(ApiMessagingRepository.conversationIdOf(null), isNull);
    });

    test('each start sends what its endpoint wants, trimming the first message', () async {
      final adapter = TableAdapter({
        'POST /messaging/conversations': (_) => {'id': 'c1'},
        'POST /messaging/conversations/supplier': (_) => {'id': 'c2'},
        'POST /messaging/conversations/company': (_) => {'id': 'c3'},
        'POST /messaging/conversations/job': (_) => {'id': 'c4'},
      });
      final repo = repoOf(adapter);
      expect(await repo.startWithPerson('u1', message: '  hi  '), 'c1');
      expect(adapter.last('POST /messaging/conversations').data, {
        'participantIds': ['u1'],
        'message': 'hi',
      });
      await repo.startWithPerson('u1', message: '   ');
      expect(adapter.last('POST /messaging/conversations').data, {
        'participantIds': ['u1'],
      });
      expect(await repo.startWithSupplier('v1'), 'c2');
      expect(adapter.last('POST /messaging/conversations/supplier').data, {'vendorId': 'v1'});
      expect(await repo.startWithCompany('co-1', 'PARTNERSHIP', message: 'Let us talk'), 'c3');
      expect(adapter.last('POST /messaging/conversations/company').data, {
        'companyId': 'co-1',
        'topic': 'PARTNERSHIP',
        'message': 'Let us talk',
      });
      expect(await repo.startWithJobContact('J1'), 'c4');
      expect(adapter.last('POST /messaging/conversations/job').data, {'jobId': 'J1'});
    });

    test('an answer with no thread in it is an error, never a silent nothing', () async {
      final adapter = TableAdapter({
        'POST /messaging/conversations': (_) => {'oops': true},
      });
      expect(repoOf(adapter).startWithPerson('u1'), throwsA(isA<StateError>()));
    });
  });

  group('the card of a shared record', () {
    RecordFacts facts(RecordType t, Map<String, dynamic> row) =>
        ApiMessagingRepository.recordFacts(t, row, apiBase: 'http://api.test/api/v1');

    test('a job: its company, place and way of working', () {
      final f = facts(RecordType.job, {
        'id': 'J1',
        'title': 'Senior Facilities Manager for STP Plant',
        'company': {'name': 'CBRE South Asia', 'logoUrl': '/uploads/logo.png'},
        'city': 'Mumbai',
        'cities': ['Mumbai'],
        'workMode': 'ONSITE',
      });
      expect(
        (f.title, f.owner, f.city, f.kind),
        ('Senior Facilities Manager for STP Plant', 'CBRE South Asia', 'Mumbai', 'ONSITE'),
      );
      expect(f.image!.url, 'http://api.test/uploads/logo.png');
      expect(
        facts(RecordType.job, {
          'id': 'J2',
          'title': 'T',
          'cities': ['Pune'],
        }).city,
        'Pune',
      );
    });

    test('a requirement: the buying company, place, budget (a string) and deadline', () {
      final f = facts(RecordType.requirement, {
        'id': 'R1',
        'title': 'Access control upgrade',
        'companyName': 'Sunrise Facilities',
        'locations': ['Pune'],
        'budget': '800000',
        'dueDate': '2026-11-09T18:29:59.999Z',
        'kind': 'ENQUIRY',
      });
      expect((f.owner, f.city, f.amount, f.kind), ('Sunrise Facilities', 'Pune', 800000, 'ENQUIRY'));
      expect(f.date, DateTime.utc(2026, 11, 9, 18, 29, 59, 999));
    });

    test('a company, a product, a mentor and an event (by its slug)', () {
      final company = facts(RecordType.company, {
        'id': 'co-1',
        'name': 'Global Infra',
        'industry': 'CRE_SERVICES',
        'city': 'Bengaluru',
        'logoUrl': '/uploads/l.png',
      });
      expect((company.title, company.city), ('Global Infra', 'Bengaluru'));
      final product = facts(RecordType.product, {
        'id': 'P1',
        'name': 'Biometric Terminal',
        'price': '18500',
        'unit': 'piece',
        'imageUrl': null,
        'company': {'name': 'SecureTech', 'logoUrl': '/uploads/s.png'},
      });
      expect((product.owner, product.amount, product.unit), ('SecureTech', 18500, 'piece'));
      expect(product.image!.url, 'http://api.test/uploads/s.png', reason: 'no photo of its own: the seller\'s logo');
      final mentor = facts(RecordType.mentor, {
        'id': 'MP1',
        'user': {'firstName': 'Rajesh', 'lastName': 'Sharma', 'avatarUrl': '/uploads/r.jpg'},
        'headline': 'VP Facility Ops',
        'yearsExperience': 14,
      });
      expect((mentor.title, mentor.owner, mentor.years), ('Rajesh Sharma', 'VP Facility Ops', 14));
      final event = facts(RecordType.event, {
        'id': 'ev-1',
        'slug': 'summit-design',
        'title': 'Summit',
        'location': 'Mumbai Convention Centre',
        'startsAt': '2026-10-27T04:30:00.000Z',
        'chapter': {'name': 'Vinfraa Chapter'},
        'council': null,
        'coverUrl': '/uploads/c.jpg',
      });
      expect((event.id, event.owner, event.city), ('summit-design', 'Vinfraa Chapter', 'Mumbai Convention Centre'));
      expect(event.ref.path, '/events/summit-design');
    });

    test('a record is read through the record\'s own public endpoint', () async {
      final adapter = TableAdapter({
        'GET /jobs/J1': (_) => {
          'id': 'J1',
          'title': 'T',
          'company': {'name': 'C'},
        },
        'GET /rfq/R1': (_) => {'id': 'R1', 'title': 'T'},
        'GET /companies/co-1': (_) => {'id': 'co-1', 'name': 'N'},
        'GET /products/P1': (_) => {'id': 'P1', 'name': 'N'},
        'GET /mentorship/mentors/MP1': (_) => {
          'id': 'MP1',
          'user': {'firstName': 'A', 'lastName': 'B'},
        },
        'GET /events/e-1': (_) => {'id': 'x', 'slug': 'e-1', 'title': 'T'},
      });
      final repo = repoOf(adapter);
      for (final ref in const [
        RecordRef(RecordType.job, 'J1'),
        RecordRef(RecordType.requirement, 'R1'),
        RecordRef(RecordType.company, 'co-1'),
        RecordRef(RecordType.product, 'P1'),
        RecordRef(RecordType.mentor, 'MP1'),
        RecordRef(RecordType.event, 'e-1'),
      ]) {
        await repo.record(ref);
      }
      expect(adapter.calls, [
        'GET /jobs/J1',
        'GET /rfq/R1',
        'GET /companies/co-1',
        'GET /products/P1',
        'GET /mentorship/mentors/MP1',
        'GET /events/e-1',
      ]);
    });

    test(
      'the share sheet\'s search: a page of each kind; requirements are the person\'s own (drafts left out) then the open board\'s',
      () async {
        final adapter = TableAdapter({
          'GET /jobs': (_) => {
            'data': [
              {
                'id': 'J1',
                'title': 'A job',
                'company': {'name': 'C'},
              },
            ],
            'meta': {},
          },
          'GET /rfq/mine': (_) => {
            'data': [
              {'id': 'R-draft', 'title': 'Draft', 'status': 'DRAFT'},
              {'id': 'R-mine', 'title': 'Mine', 'status': 'PUBLISHED'},
            ],
          },
          'GET /rfq': (_) => {
            'data': [
              {'id': 'R-mine', 'title': 'Mine', 'status': 'PUBLISHED'},
              {'id': 'R-board', 'title': 'Board', 'status': 'PUBLISHED'},
            ],
          },
        });
        final repo = repoOf(adapter);
        final jobs = await repo.searchRecords(RecordType.job, ' crane ');
        expect(adapter.queryOf('GET /jobs'), {'limit': 6, 'search': 'crane'});
        expect(jobs.single.title, 'A job');
        final rfqs = await repo.searchRecords(RecordType.requirement, '');
        expect(rfqs.map((r) => r.id), ['R-mine', 'R-board']);
        expect(adapter.queryOf('GET /rfq'), {'limit': 6});
      },
    );
  });
}
