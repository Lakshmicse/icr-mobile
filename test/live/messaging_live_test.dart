@Tags(['live'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/core/api/api_error.dart';
import 'package:icr_mobile/features/messaging/api_messaging_repository.dart';
import 'package:icr_mobile/features/messaging/conversation_controller.dart';
import 'package:icr_mobile/features/messaging/messaging_format.dart';
import 'package:icr_mobile/features/messaging/messaging_models.dart';
import 'package:icr_mobile/features/messaging/messaging_repository.dart';
import 'package:icr_mobile/features/notifications/unread_counts.dart';

import 'live.dart';

/// Messages against the local API, through the app's own repository and
/// controllers: every read parsed from what the API really answers (the
/// threads `tool/seed/inbox.ts` gives Bharat Buyer), and every write.
///
/// Bharat's own threads are only READ, except star and pin on one thread
/// (put back). The writes run between Bharat and the Inbox Persona (Anita Rao)
/// in the thread they share, and between Anita and a supplier's inbox (the
/// supplier's seller, Vikram Vendor, answers as the company) in a thread
/// Bharat is not in. Every message sent is withdrawn at the end (a withdrawn
/// message stays as a blank row; re-running the seed clears them), and the
/// one report filed cannot be taken back (the seed's next run clears it with
/// its message). Starting a thread reuses the seeded ones, so a run never
/// leaves a new thread behind.
///
/// Run: `flutter test test/live/messaging_live_test.dart --concurrency=1`
const vendor = LivePerson('vendor@icr.dev', 'Vendor@123', 'Vikram Vendor');
const anita = LivePerson('inbox.friend@inbox-seed.icr.test', 'Inbox@12345', 'Anita Rao');

const _sarah = 'inbox-seed-conv-sarah';
const _company = 'inbox-seed-conv-company';
const _david = 'inbox-seed-conv-david';
const _rfq = 'inbox-seed-conv-rfq';
const _friend = 'inbox-seed-conv-friend';
const _sandbox = 'inbox-seed-conv-sandbox';
const _duo = 'inbox-seed-conv-duo';
const _enquiry = 'inbox-seed-conv-enquiry';
const _supplierCompany = 'cmupai6jm01esmyzcwg2fprhe';
const _globalInfra = 'design-lj-co-global-infra';

Future<ApiMessagingRepository> _repo([LivePerson who = bharat]) async =>
    ApiMessagingRepository(api: await liveClient(who));

/// What the API says to a call it refuses; fails when it accepts.
Future<ApiError> _refusal(Future<Object?> Function() call) async {
  try {
    await call();
  } catch (e) {
    return ApiError.from(e);
  }
  fail('the API accepted a call that should have been refused');
}

/// A one-page PDF, text only: something real to upload.
Uint8List _pdf(String line) {
  final stream = 'BT /F1 14 Tf 1 0 0 1 56 780 Tm ($line) Tj ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${stream.length} >>\nstream\n$stream\nendstream',
  ];
  var out = '%PDF-1.4\n';
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    out += '${i + 1} 0 obj\n${objects[i]}\nendobj\n';
  }
  final xref = out.length;
  out += 'xref\n0 ${objects.length + 1}\n0000000000 65535 f \n';
  for (final o in offsets) {
    out += '${o.toString().padLeft(10, '0')} 00000 n \n';
  }
  out += 'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n';
  return Uint8List.fromList(latin1.encode(out));
}

void main() {
  group('reading (Bharat Buyer)', () {
    liveTest('the inbox: his own messages, with the unread count the badge shows', () async {
      final repo = await _repo();
      final inboxes = await repo.inboxes();
      expect(inboxes.single.personal, isTrue);
      expect(inboxes.single.id, 'personal');
      final unread = await repo.unreadCount();
      expect(unread.count, unread.personal);
      expect(inboxes.single.unread, unread.personal);
      expect(unread.companies, isEmpty);
      expect(await repo.viewerId(), isNotEmpty);
    });

    liveTest('the list as the app asks for it: every seeded thread reads, pinned ones are set apart', () async {
      final repo = await _repo();
      final page = await repo.conversations(const ConversationQuery());
      final byId = {for (final c in page.conversations) c.id: c};
      expect(page.total, greaterThanOrEqualTo(6));
      expect(
        page.conversations.every((c) => !c.pinned),
        isTrue,
        reason: 'pinned threads are listed apart (excludePinned)',
      );

      final sarah = byId[_sarah]!;
      expect(sarah.kind, ConversationKind.direct);
      expect(sarah.unread, greaterThanOrEqualTo(2));
      expect(sarah.participants.map((p) => p.fullName), containsAll(['Bharat Buyer', 'Sarah Jenkins']));
      expect(sarah.participants.firstWhere((p) => p.firstName == 'Sarah').photo!.url, startsWith('http'));
      expect(sarah.lastMessage!.body, isNotEmpty);

      final company = byId[_company]!;
      expect(company.kind, ConversationKind.company);
      expect(company.counterpartCompany!.name, 'Global Infra Solutions');
      expect(company.parties.single.topic, 'CAREERS');
      expect(company.lastMessage!.senderCompany!.id, _globalInfra, reason: 'written as the company');

      final rfq = byId[_rfq]!;
      expect(rfq.kind, ConversationKind.requirement);
      expect(rfq.rfqId, isNotNull);
      expect(rfq.contextLabel, isNotEmpty);
      expect(rfq.counterpartCompany!.name, 'Bengaluru Care 101');

      expect(byId[_friend]!.kind, ConversationKind.direct);
      expect(byId.containsKey(_enquiry), isTrue);
    });

    liveTest('pinned, starred and unread are what the API\'s filters give', () async {
      final repo = await _repo();
      final pinned = await repo.pinned();
      expect(pinned.map((c) => c.id), contains(_david));
      expect(pinned.every((c) => c.pinned), isTrue);
      final david = pinned.firstWhere((c) => c.id == _david);
      expect(david.starred, isTrue);
      expect(david.lastMessage!.senderId, isNotEmpty);

      final unread = await repo.conversations(const ConversationQuery(filter: InboxFilter.unread, search: ''));
      expect(unread.conversations.every((c) => c.unread > 0), isTrue);
      expect(unread.conversations.map((c) => c.id), containsAll([_sarah, _company, _rfq]));

      final starred = await repo.conversations(const ConversationQuery(filter: InboxFilter.starred));
      expect(starred.conversations.map((c) => c.id), contains(_david));
      expect(starred.conversations.every((c) => c.starred), isTrue);
    });

    liveTest('a kind narrows the list the way the website\'s does', () async {
      final repo = await _repo();
      final requirement = await repo.conversations(const ConversationQuery(kind: InboxKind.requirement));
      expect(requirement.conversations.map((c) => c.id), contains(_rfq));
      expect(requirement.conversations.every((c) => c.kind?.isRequirement ?? false), isTrue);
      final direct = await repo.conversations(const ConversationQuery(kind: InboxKind.direct));
      expect(direct.conversations.map((c) => c.id), containsAll([_sarah, _company]));
      expect(
        direct.conversations.every((c) => c.kind == ConversationKind.direct || c.kind == ConversationKind.company),
        isTrue,
      );
      final mentorship = await repo.conversations(const ConversationQuery(kind: InboxKind.mentorship));
      expect(
        mentorship.conversations.every(
          (c) => const [
            ConversationKind.mentorship,
            ConversationKind.groupSession,
            ConversationKind.consultation,
          ].contains(c.kind),
        ),
        isTrue,
      );
    });

    liveTest('a name finds its thread, and message text finds the message and its thread', () async {
      final repo = await _repo();
      final byName = await repo.conversations(const ConversationQuery(search: 'Sarah'));
      expect(byName.conversations.map((c) => c.id), contains(_sarah));
      final hits = await repo.searchMessages('checklist', inbox: 'personal');
      expect(hits.map((h) => h.messageId), contains('inbox-seed-m-david-1'));
      final hit = hits.firstWhere((h) => h.messageId == 'inbox-seed-m-david-1');
      expect(hit.snippet.toLowerCase(), contains('checklist'));
      expect(hit.conversationId, _david);
      expect(hit.sender!.firstName, 'David');
      expect(await repo.searchMessages('x'), isEmpty);
      final window = await repo.thread(hit.conversationId, take: 50);
      expect(window.messages.map((m) => m.id), contains(hit.messageId));
    });

    liveTest(
      'a thread pages back with ?take and before: oldest first, the withdrawn one blank, "seen" on the last',
      () async {
        final repo = await _repo();
        final newest = await repo.thread(_david, take: 2);
        expect(newest.hasMore, isTrue);
        expect(newest.messages, hasLength(2));
        expect(newest.messages.first.createdAt.isBefore(newest.messages.last.createdAt), isTrue);
        expect(newest.conversation.pinned, isTrue);
        expect(newest.conversation.starred, isTrue);
        expect(newest.conversation.kind, isNull, reason: 'the detail read carries no kind: the list row does');
        expect(newest.seen, isNotNull, reason: 'his last message was read by the other side');
        expect(newest.seen!.messageId, newest.messages.last.id);
        expect(newest.messages.first.deleted, isTrue);
        expect(newest.messages.first.body, isEmpty);

        final earlier = await repo.older(_david, newest.messages.first.id, take: 5);
        expect(earlier.hasMore, isFalse);
        expect(earlier.messages.map((m) => m.id), ['inbox-seed-m-david-1', 'inbox-seed-m-david-2']);
        expect(earlier.messages.first.hasAttachment, isTrue);
        expect(earlier.messages.first.attachmentName, 'Site feasibility checklist.pdf');
        expect(earlier.messages.first.attachmentMime, 'application/pdf');

        final later = await repo.newer(_david, earlier.messages.first.id);
        expect(later.messages.map((m) => m.id), [
          'inbox-seed-m-david-2',
          'inbox-seed-m-david-3',
          'inbox-seed-m-david-4',
        ]);
        expect(later.seen!.messageId, 'inbox-seed-m-david-4');
      },
    );

    liveTest('a reply carries the message it quotes; a shared job link is in the body', () async {
      final repo = await _repo();
      final w = await repo.thread(_sarah, take: 50);
      final reply = w.messages.firstWhere((m) => m.replyTo != null);
      expect(reply.replyTo!.id, 'inbox-seed-m-sarah-1');
      expect(reply.replyTo!.senderName, 'Bharat Buyer');
      expect(reply.replyTo!.excerpt, isNotEmpty);
      expect(w.messages.any((m) => m.body.contains('/jobs/design-lj-job-extra-1')), isTrue);
    });

    liveTest('why each thread exists: a requirement, a company, a plain one', () async {
      final repo = await _repo();
      final rfq = (await repo.context(_rfq))!;
      expect((rfq.kind, rfq.perspective), (ConversationKind.requirement, Perspective.owner));
      expect(rfq.company!.name, 'Bengaluru Care 101');
      expect(rfq.company!.role, 'SUPPLIER');
      expect(rfq.requirement!.title, isNotEmpty);
      expect(rfq.requirement!.status, 'PUBLISHED');
      final company = (await repo.context(_company))!;
      expect(company.kind, ConversationKind.company);
      expect(company.company!.name, 'Global Infra Solutions');
      expect(company.company!.logo!.url, startsWith('http'));
      final direct = (await repo.context(_sarah))!;
      expect((direct.kind, direct.person!.firstName), (ConversationKind.direct, 'Sarah'));
      expect(direct.requirement, isNull);
    });

    liveTest("a thread that is not his is refused with the API's own status", () async {
      final repo = await _repo();
      expect((await _refusal(() => repo.thread(_sandbox))).statusCode, 403);
      expect((await _refusal(() => repo.thread('no-such-thread'))).statusCode, 404);
    });

    liveTest('who "New message" can reach: people and suppliers; under two letters nothing is asked', () async {
      final repo = await _repo();
      expect((await repo.recipients('s')).isEmpty, isTrue);
      final people = await repo.recipients('Sarah');
      expect(people.people.map((p) => p.person.fullName), contains('Sarah Jenkins'));
      final suppliers = await repo.recipients('Bengaluru Care');
      final care = suppliers.suppliers.firstWhere((s) => s.name == 'Bengaluru Care 101');
      expect((care.companyId, care.city), (_supplierCompany, 'Bengaluru'));
      expect(care.vendorId, isNotEmpty);
    });

    liveTest('the app-wide badge reads the same number the inbox does', () async {
      final api = await liveClient();
      final counts = UnreadCounts.api(api, interval: const Duration(hours: 1));
      addTearDown(counts.dispose);
      await counts.refresh();
      expect(counts.messages, (await ApiMessagingRepository(api: api).unreadCount()).count);
    });
  });

  group('a seller answering for a company (Vikram Vendor)', () {
    liveTest('has his own inbox and the company\'s, with the topics it takes', () async {
      final repo = await _repo(vendor);
      final inboxes = await repo.inboxes();
      expect(inboxes.first.personal, isTrue);
      final company = inboxes.firstWhere((i) => !i.personal);
      expect(company.id, _supplierCompany);
      expect(company.name, 'Bengaluru Care 101');
      expect(company.topics, containsAll(['SALES', 'PROCUREMENT']));
      final unread = await repo.unreadCount();
      expect(unread.companies.keys, contains(_supplierCompany));
    });

    liveTest(
      'the company inbox lists its threads with the party\'s status; Open, Done and Mine are the API\'s own views',
      () async {
        final repo = await _repo(vendor);
        const q = ConversationQuery(inbox: _supplierCompany);
        final open = await repo.conversations(q);
        final ids = open.conversations.map((c) => c.id);
        expect(ids, containsAll([_rfq, _sandbox, _enquiry]));
        final rfq = open.conversations.firstWhere((c) => c.id == _rfq);
        expect(rfq.asCompanyId, _supplierCompany);
        expect(rfq.myParty!.status, ThreadStatus.open);
        expect(rfq.myParty!.topic, 'SALES');
        expect(rfq.kind, ConversationKind.requirement);
        expect(
          (await repo.conversations(q.copyWith(view: CompanyInboxView.done))).conversations.map((c) => c.id),
          isNot(contains(_rfq)),
        );
        final procurement = await repo.conversations(q.copyWith(topic: 'PROCUREMENT'));
        expect(procurement.conversations.every((c) => c.myParty?.topic == 'PROCUREMENT'), isTrue);
        expect(procurement.conversations.map((c) => c.id), isNot(contains(_rfq)));
      },
    );

    liveTest('the thread read as the company, and why it exists from the supplier\'s side', () async {
      final repo = await _repo(vendor);
      final w = await repo.thread(_rfq, asCompanyId: _supplierCompany);
      expect(w.conversation.asCompanyId, _supplierCompany);
      expect(w.messages.any((m) => m.senderCompany?.id == _supplierCompany), isTrue);
      final ctx = (await repo.context(_rfq, asCompanyId: _supplierCompany))!;
      expect(ctx.perspective, Perspective.supplier);
      expect(ctx.kind, ConversationKind.requirement);
    });

    liveTest('Done, back to Open, Assign to me and Unassign are kept by the API (put back after)', () async {
      final repo = await _repo(vendor);
      const q = ConversationQuery(inbox: _supplierCompany);
      Future<ThreadParty> party() async => (await repo.conversations(
        q.copyWith(view: CompanyInboxView.open),
      )).conversations.firstWhere((c) => c.id == _enquiry).myParty!;
      final me = await repo.viewerId();
      addTearDown(() async {
        await repo.updateCompanyThread(_enquiry, companyId: _supplierCompany, status: ThreadStatus.open);
        await repo.updateCompanyThread(_enquiry, companyId: _supplierCompany, unassign: true);
      });

      final assigned = await repo.updateCompanyThread(_enquiry, companyId: _supplierCompany, assigneeId: me);
      expect(assigned.assignee!.id, me);
      expect(
        (await repo.conversations(q.copyWith(view: CompanyInboxView.mine))).conversations.map((c) => c.id),
        contains(_enquiry),
      );
      expect((await party()).assignee!.id, me);

      final done = await repo.updateCompanyThread(_enquiry, companyId: _supplierCompany, status: ThreadStatus.done);
      expect(done.status, ThreadStatus.done);
      expect(
        (await repo.conversations(q.copyWith(view: CompanyInboxView.done))).conversations.map((c) => c.id),
        contains(_enquiry),
      );
      expect(
        (await repo.conversations(q.copyWith(view: CompanyInboxView.open))).conversations.map((c) => c.id),
        isNot(contains(_enquiry)),
      );

      final spam = await repo.updateCompanyThread(_enquiry, companyId: _supplierCompany, status: ThreadStatus.spam);
      expect(spam.status, ThreadStatus.spam);
      expect(
        (await repo.conversations(q.copyWith(view: CompanyInboxView.spam))).conversations.map((c) => c.id),
        contains(_enquiry),
      );

      await repo.updateCompanyThread(_enquiry, companyId: _supplierCompany, status: ThreadStatus.open);
      final loose = await repo.updateCompanyThread(_enquiry, companyId: _supplierCompany, unassign: true);
      expect(loose.assignee, isNull);
      expect((await party()).status, ThreadStatus.open);
    });
  });

  group('writing (Bharat and the Inbox Persona)', () {
    liveTest('send, read, "seen", reply, delete: both sides see each step; the badge follows', () async {
      final bob = await _repo(vendor);
      final ann = await _repo(anita);
      final sent = <(ApiMessagingRepository, String)>[];
      addTearDown(() async {
        for (final (repo, id) in sent) {
          try {
            await repo.deleteMessage(_duo, id);
          } catch (_) {}
        }
      });
      await ann.markRead(_duo);
      Future<int> unreadOf(ApiMessagingRepository r, String c) async => (await r.conversations(
        const ConversationQuery(filter: InboxFilter.unread),
      )).conversations.where((x) => x.id == c).fold<int>(0, (n, x) => n + x.unread);

      final m1 = await bob.send(_duo, body: 'live test: are you free on Friday?');
      sent.add((bob, m1.id));
      expect(m1.senderId, await bob.viewerId());
      expect(m1.body, 'live test: are you free on Friday?');
      expect(m1.sender!.firstName, 'Vikram');
      expect(m1.readAt, isNull);

      // She has it, unread, and the badge says so.
      expect(await unreadOf(ann, _duo), 1);
      final hers = await ann.thread(_duo, take: 50);
      expect(hers.messages.last.id, m1.id);
      expect(hers.seen?.messageId, isNot(m1.id), reason: 'her "seen" is about her own messages, not his');

      // She reads it: his message is "seen".
      await ann.markRead(_duo);
      expect(await unreadOf(ann, _duo), 0);
      final his = await bob.thread(_duo, take: 50);
      expect(his.seen!.messageId, m1.id);
      expect(his.messages.last.readAt, isNotNull);

      // She replies to it; he sees the quote and one unread.
      final m2 = await ann.send(_duo, body: 'Yes, Friday works.', replyToId: m1.id);
      sent.add((ann, m2.id));
      expect(m2.replyTo!.id, m1.id);
      expect(m2.replyTo!.excerpt, 'live test: are you free on Friday?');
      expect(await unreadOf(bob, _duo), 1);
      final newer = await bob.newer(_duo, m1.id);
      expect(newer.messages.map((m) => m.id), [m2.id], reason: 'what a poll catches up on');
      await bob.markRead(_duo);
      expect(await unreadOf(bob, _duo), 0);

      // He withdraws his: blank for her too, and her quote of it says so.
      final at = await bob.deleteMessage(_duo, m1.id);
      expect(at.isAfter(DateTime(2026)), isTrue);
      final after = await ann.thread(_duo, take: 50);
      final blank = after.messages.firstWhere((m) => m.id == m1.id);
      expect(blank.deleted, isTrue);
      expect(blank.body, isEmpty);
      expect(after.messages.firstWhere((m) => m.id == m2.id).replyTo!.deleted, isTrue);
      // He cannot withdraw hers.
      Object? refused;
      try {
        await bob.deleteMessage(_duo, m2.id);
      } catch (e) {
        refused = e;
      }
      expect(ApiError.from(refused!).statusCode, anyOf(403, 404));
    });

    liveTest(
      'a file: uploaded, sent, opened by the other side with her session, and closed again when withdrawn',
      () async {
        final bob = await _repo(vendor);
        final ann = await _repo(anita);
        final ids = <String>[];
        addTearDown(() async {
          for (final id in ids) {
            try {
              await bob.deleteMessage(_duo, id);
            } catch (_) {}
          }
        });
        final bytes = _pdf('Live test site checklist');
        final up = await bob.upload(PickedAttachment(name: 'Live checklist.pdf', bytes: bytes));
        expect(up.url, startsWith('/uploads/'));
        expect(up.name, 'Live checklist.pdf');
        expect(up.mimeType, 'application/pdf');
        expect(up.size, bytes.length);

        final m = await bob.send(_duo, body: '', attachmentUrl: up.url);
        ids.add(m.id);
        expect(
          (m.attachmentName, m.attachmentMime, m.attachmentSize),
          ('Live checklist.pdf', 'application/pdf', bytes.length),
        );
        expect(m.hasAttachment, isTrue);

        // She reads it with her own session; a stranger's session is refused.
        final got = await ann.download(m.attachmentUrl!);
        expect(got, bytes);
        Object? refused;
        try {
          await (await _repo()).download(m.attachmentUrl!);
        } catch (e) {
          refused = e;
        }
        expect(
          ApiError.from(refused!).statusCode,
          anyOf(401, 403, 404),
          reason: 'private to the two people in the thread',
        );

        // Withdrawn: the file closes with it.
        await bob.deleteMessage(_duo, m.id);
        refused = null;
        try {
          await ann.download(m.attachmentUrl!);
        } catch (e) {
          refused = e;
        }
        expect(refused, isNotNull);
        expect(ApiError.from(refused!).statusCode, anyOf(403, 404));
      },
    );

    liveTest('a file the API would not take is refused with its sentence', () async {
      final bob = await _repo(vendor);
      Object? refused;
      try {
        await bob.upload(PickedAttachment(name: 'setup.exe', bytes: Uint8List.fromList([77, 90, 0, 0])));
      } catch (e) {
        refused = e;
      }
      final error = ApiError.from(refused!);
      expect(error.statusCode, anyOf(400, 415));
      expect(error.message, isNotEmpty);
    });

    liveTest('an empty message, and one with nothing but spaces, are refused', () async {
      final bob = await _repo(vendor);
      Object? refused;
      try {
        await bob.send(_duo, body: '   ');
      } catch (e) {
        refused = e;
      }
      expect(ApiError.from(refused!).statusCode, 400);
    });

    liveTest('star and pin on a thread: kept, listed by their filters, and put back', () async {
      final repo = await _repo();
      addTearDown(() => repo.setPreference(_friend, starred: false, pinned: false));
      final starred = await repo.setPreference(_friend, starred: true);
      expect(starred, (starred: true, pinned: false));
      expect(
        (await repo.conversations(const ConversationQuery(filter: InboxFilter.starred))).conversations.map((c) => c.id),
        contains(_friend),
      );
      final pinned = await repo.setPreference(_friend, pinned: true);
      expect(pinned.pinned, isTrue);
      expect((await repo.pinned()).map((c) => c.id), contains(_friend));
      expect((await repo.thread(_friend, take: 1)).conversation.pinned, isTrue);
      expect(
        (await repo.conversations(const ConversationQuery())).conversations.map((c) => c.id),
        isNot(contains(_friend)),
        reason: 'listed above, not in the rest',
      );
      final back = await repo.setPreference(_friend, starred: false, pinned: false);
      expect(back, (starred: false, pinned: false));
      expect((await repo.pinned()).map((c) => c.id), isNot(contains(_friend)));
    });

    liveTest('"Mark all as read" reads every waiting thread of hers and brings her unread to nothing', () async {
      final bob = await _repo(vendor);
      final ann = await _repo(anita);
      final sent = <String>[];
      addTearDown(() async {
        for (final id in sent) {
          try {
            await bob.deleteMessage(_duo, id);
          } catch (_) {}
        }
      });
      sent.add((await bob.send(_duo, body: 'live test: one')).id);
      sent.add((await bob.send(_duo, body: 'live test: two')).id);
      expect((await ann.unreadCount()).personal, greaterThanOrEqualTo(2));
      expect(await ann.markAllRead(), greaterThanOrEqualTo(2));
      expect((await ann.unreadCount()).count, 0);
      expect((await ann.inboxes()).first.unread, 0);
    });

    liveTest('a message is reported with a reason and a note; reporting it twice, or one\'s own, is refused', () async {
      final bob = await _repo(vendor);
      final ann = await _repo(anita);
      final m = await bob.send(_duo, body: 'live test: this is only a test message');
      addTearDown(() => bob.deleteMessage(_duo, m.id).then((_) {}, onError: (_) {}));
      await ann.report(m.id, 'OTHER', note: 'Filed by the mobile app\'s live test');
      Object? again;
      try {
        await ann.report(m.id, 'SPAM');
      } catch (e) {
        again = e;
      }
      expect(ApiError.from(again!).statusCode, 409);
      Object? own;
      try {
        await bob.report(m.id, 'SPAM');
      } catch (e) {
        own = e;
      }
      expect(ApiError.from(own!).statusCode, 400);
    });

    liveTest(
      'the supplier\'s seller answers as the company: the persona sees the company, her unread follows',
      () async {
        final ann = await _repo(anita);
        final vik = await _repo(vendor);
        final sent = <String>[];
        addTearDown(() async {
          for (final id in sent) {
            try {
              await vik.deleteMessage(_sandbox, id);
            } catch (_) {}
          }
        });
        await ann.markRead(_sandbox);
        final m = await vik.send(_sandbox, body: 'live test: yes, we cover Chennai.', asCompanyId: _supplierCompany);
        sent.add(m.id);
        expect(m.senderCompany!.id, _supplierCompany);
        expect(m.senderCompany!.name, 'Bengaluru Care 101');

        final row = (await ann.conversations(
          const ConversationQuery(),
        )).conversations.firstWhere((c) => c.id == _sandbox);
        expect(row.unread, 1);
        expect(row.kind, ConversationKind.company);
        expect(row.counterpartCompany!.name, 'Bengaluru Care 101');
        expect(row.lastMessage!.senderCompany!.name, 'Bengaluru Care 101');
        final w = await ann.thread(_sandbox);
        expect(w.messages.last.fromMySide(await ann.viewerId(), null), isFalse);
        await ann.markRead(_sandbox);

        // And what she writes reaches the company's inbox, unread.
        final back = await ann.send(_sandbox, body: 'live test: thank you.');
        sent.add(back.id);
        final inbox = (await vik.conversations(
          const ConversationQuery(inbox: _supplierCompany),
        )).conversations.firstWhere((c) => c.id == _sandbox);
        expect(inbox.unread, 1);
        await vik.markRead(_sandbox, asCompanyId: _supplierCompany);
        expect(
          (await vik.conversations(
            const ConversationQuery(inbox: _supplierCompany),
          )).conversations.firstWhere((c) => c.id == _sandbox).unread,
          0,
        );
        await ann.deleteMessage(_sandbox, back.id);
      },
    );

    liveTest(
      'an open thread catches up by polling: a message from the other side arrives, is read, and "seen" follows',
      () async {
        final bobApi = await liveClient(vendor);
        final bob = ApiMessagingRepository(api: bobApi);
        final ann = await _repo(anita);
        final c = ConversationController(bob, conversationId: _duo, viewerId: await bob.viewerId());
        addTearDown(c.dispose);
        final sent = <(ApiMessagingRepository, String)>[];
        addTearDown(() async {
          for (final (r, id) in sent) {
            try {
              await r.deleteMessage(_duo, id);
            } catch (_) {}
          }
        });
        await c.start();
        expect(c.loaded, isTrue);
        expect(c.display.name, 'Anita Rao');
        final before = c.messages.length;

        final arrived = await ann.send(_duo, body: 'live test: poll me');
        sent.add((ann, arrived.id));
        await c.poll();
        expect(c.messages.length, before + 1);
        expect(c.messages.last.id, arrived.id);
        expect(c.messages.last.readAt, isNotNull, reason: 'the poll read it');

        // His reply goes through the controller; her side reads it; the next poll shows "Seen".
        expect(await c.send('live test: polled'), isNull);
        final mine = c.messages.last;
        sent.add((bob, mine.id));
        expect(c.pending, isEmpty);
        await ann.markRead(_duo);
        await c.poll();
        expect(c.seenMessageId, mine.id);
      },
    );
  });

  group('starting a thread reuses the seeded ones (no new thread is left behind)', () {
    liveTest('a person, a company page, a supplier by listing, a supplier about a requirement', () async {
      final repo = await _repo();
      final friend = (await repo.thread(
        _friend,
        take: 1,
      )).conversation.participants.firstWhere((p) => p.firstName == 'Anita');
      expect(await repo.startWithPerson(friend.id), _friend);
      expect(await repo.startWithPerson(friend.id), _friend, reason: 'asked again: the same thread');

      expect(await repo.startWithCompany(_globalInfra, 'CAREERS'), _company);

      final care = (await repo.recipients(
        'Bengaluru Care',
      )).suppliers.firstWhere((s) => s.name == 'Bengaluru Care 101');
      expect(await repo.startWithSupplier(care.vendorId), _enquiry);
      final rfqId = (await repo.thread(_rfq, take: 1)).conversation.rfqId!;
      expect(await repo.startWithSupplier(care.vendorId, rfqId: rfqId), _rfq);
      expect(await repo.openForRfq(rfqId, supplierCompanyId: _supplierCompany), _rfq);
    });

    liveTest(
      'a job\'s hiring contact, a pairing, a group room and a bought session open the same thread every time',
      () async {
        final repo = await _repo();
        final job = await repo.startWithJobContact('design-lj-job-global-infra');
        expect(await repo.startWithJobContact('design-lj-job-global-infra'), job);
        final jobThread = (await repo.thread(job, take: 1)).conversation;
        expect(jobThread.title, contains('Global Infra Solutions'));

        final pairing = await repo.openForMentorship('dsgn-mentoring-pair-bharat-anand');
        expect(await repo.openForMentorship('dsgn-mentoring-pair-bharat-anand'), pairing);
        expect(
          (await repo.thread(pairing, take: 1)).conversation.participants.map((p) => p.firstName),
          containsAll(['Bharat', 'Anand']),
        );

        final room = await repo.openForGroupSession('dsgn-mentoring-group-clinic');
        expect(await repo.openForGroupSession('dsgn-mentoring-group-clinic'), room);
        expect((await repo.context(room))!.kind, ConversationKind.groupSession);

        // A bought 1:1 shares the pair's thread (its mentor is the same person).
        final purchase = await repo.openForPurchase('dsgn-mentoring-buy-bharat-accepted');
        expect(await repo.openForPurchase('dsgn-mentoring-buy-bharat-accepted'), purchase);
        expect((await repo.thread(purchase, take: 1)).conversation.id, purchase);
      },
    );

    liveTest("what the API refuses stays the API's sentence", () async {
      final repo = await _repo();
      final job = await _refusal(() => repo.startWithJobContact('no-such-job'));
      expect(job.statusCode, 404);
      expect(job.message, isNotEmpty);
      expect((await _refusal(() => repo.startWithCompany('no-such-company', 'SALES'))).statusCode, 404);
      expect((await _refusal(() => repo.openForMentorship('no-such-pairing'))).statusCode, anyOf(403, 404));
    });
  });

  group('shared records (the card and the share sheet)', () {
    liveTest('each of the six kinds lists something, and the first one reads back as a card with a title', () async {
      final repo = await _repo();
      for (final type in RecordType.values) {
        final found = await repo.searchRecords(type, '');
        expect(found, isNotEmpty, reason: type.name);
        final first = found.first;
        expect(first.title, isNotEmpty, reason: type.name);
        final card = await repo.record(first.ref);
        expect(card.title, first.title, reason: '${type.name}: the card is the same record the list gave');
        expect(card.type, type);
      }
    });

    liveTest('a job, a requirement and an event show their owner, place and date', () async {
      final repo = await _repo();
      final job = await repo.record(const RecordRef(RecordType.job, 'design-lj-job-global-infra'));
      expect(job.owner, 'Global Infra Solutions');
      expect(job.title, 'Senior Facilities Manager');
      final events = await repo.searchRecords(RecordType.event, 'Summit');
      final event = await repo.record(events.first.ref);
      expect(event.date, isNotNull);
      expect(event.id, isNot(contains(' ')), reason: 'an event is linked by its slug');
      final rfqs = await repo.searchRecords(RecordType.requirement, '');
      expect((await repo.record(rfqs.first.ref)).owner, isNotNull);
    });

    liveTest('a search narrows a kind, and a record the reader may not see is refused (404), never leaked', () async {
      final repo = await _repo();
      final narrowed = await repo.searchRecords(RecordType.company, 'Global Infra');
      expect(narrowed.map((r) => r.title), contains('Global Infra Solutions'));
      Object? refused;
      try {
        await repo.record(const RecordRef(RecordType.job, 'no-such-job'));
      } catch (e) {
        refused = e;
      }
      expect(ApiError.from(refused!).statusCode, 404);
    });

    liveTest('a record shared in a message reads back as a card link in its thread', () async {
      final bob = await _repo(vendor);
      final ann = await _repo(anita);
      final link = 'https://icr.org.in${const RecordRef(RecordType.job, 'design-lj-job-global-infra').path}';
      final m = await bob.send(_duo, body: 'live test: look at this\n$link');
      addTearDown(() => bob.deleteMessage(_duo, m.id).then((_) {}, onError: (_) {}));
      final theirs = (await ann.thread(_duo, take: 5)).messages.firstWhere((x) => x.id == m.id);
      expect(theirs.body, contains(link));
      final shared = splitRecordLinks(theirs.body, recordOrigins());
      expect(shared.records, [const RecordRef(RecordType.job, 'design-lj-job-global-infra')]);
      expect(shared.text, 'live test: look at this');
    });
  });
}
